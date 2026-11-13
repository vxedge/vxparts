// vxlola: one-way latency of an Eclipse S-CORE mw::com (LoLa) event between two processes.
//
//   vxlola send <mw_com_config.json> --size <bytes> --rate <hz> [--duration <s>]
//   vxlola recv <mw_com_config.json> --count <n> [--warmup <n>] [--timeout <s>]
//
// The receiver reports the payload size the samples carried, as the sender set it.
//
// The sender fills <size> bytes of each sample, stamps it with CLOCK_MONOTONIC just before Send()
// and sends at <rate> Hz until its duration ends or it gets SIGTERM. The receiver is woken by the
// event's receive handler, reads the sample's payload, and stamps it on reading. Both processes
// share the host's monotonic clock, so receive minus send is the one-way latency, notification
// and payload read included. The receiver prints one JSON line with the latency distribution in
// nanoseconds and the samples lost (sequence gaps), then exits.
//
// SPDX-License-Identifier: Apache-2.0

#include "score/mw/com/types.h"
#include "score/mw/com/runtime.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <csignal>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <string_view>
#include <thread>
#include <vector>

namespace vxlola
{

constexpr std::size_t kMaxPayload = 1024U * 1024U;
constexpr std::string_view kInstance{"vxedge/vxlola"};

struct LatencySample
{
    std::uint64_t seq;
    std::int64_t t_send_ns;
    std::uint32_t size;
    std::array<std::uint8_t, kMaxPayload> payload;
};

template <typename T>
struct LatencyInterface : public T::Base
{
    using T::Base::Base;
    typename T::template Event<LatencySample> latency_event{*this, "latency_event"};
};

using LatencyProxy = score::mw::com::AsProxy<LatencyInterface>;
using LatencySkeleton = score::mw::com::AsSkeleton<LatencyInterface>;

std::atomic<bool> g_stop{false};

void OnSignal(int) { g_stop.store(true); }

std::int64_t NowNs()
{
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

struct Args
{
    std::string role;
    std::string config;
    std::size_t size{64};
    double rate_hz{1000.0};
    double duration_s{0.0};
    std::size_t count{10000};
    std::size_t warmup{100};
    double timeout_s{120.0};
};

[[noreturn]] void Usage()
{
    std::fprintf(stderr,
                 "usage: vxlola send <mw_com_config.json> --size <bytes> --rate <hz> [--duration <s>]\n"
                 "       vxlola recv <mw_com_config.json> --count <n> [--warmup <n>] [--timeout <s>]\n");
    std::exit(2);
}

Args Parse(int argc, char** argv)
{
    if (argc < 3)
    {
        Usage();
    }
    Args a;
    a.role = argv[1];
    a.config = argv[2];
    for (int i = 3; i + 1 < argc; i += 2)
    {
        const std::string_view k{argv[i]};
        const char* v = argv[i + 1];
        if (k == "--size")
            a.size = std::strtoull(v, nullptr, 10);
        else if (k == "--rate")
            a.rate_hz = std::strtod(v, nullptr);
        else if (k == "--duration")
            a.duration_s = std::strtod(v, nullptr);
        else if (k == "--count")
            a.count = std::strtoull(v, nullptr, 10);
        else if (k == "--warmup")
            a.warmup = std::strtoull(v, nullptr, 10);
        else if (k == "--timeout")
            a.timeout_s = std::strtod(v, nullptr);
        else
            Usage();
    }
    if ((a.role != "send" && a.role != "recv") || a.size == 0 || a.size > kMaxPayload || a.rate_hz <= 0.0 ||
        a.count == 0)
    {
        Usage();
    }
    return a;
}

score::mw::com::InstanceSpecifier Instance()
{
    auto r = score::mw::com::InstanceSpecifier::Create(std::string{kInstance});
    if (!r.has_value())
    {
        std::fprintf(stderr, "vxlola: bad instance specifier\n");
        std::exit(1);
    }
    return std::move(r).value();
}

int Send(const Args& a)
{
    auto skeleton_result = LatencySkeleton::Create(Instance());
    if (!skeleton_result.has_value())
    {
        std::fprintf(stderr, "vxlola send: skeleton not created\n");
        return 1;
    }
    auto& skeleton = skeleton_result.value();
    if (!skeleton.OfferService().has_value())
    {
        std::fprintf(stderr, "vxlola send: service not offered\n");
        return 1;
    }
    const auto period = std::chrono::nanoseconds{static_cast<std::int64_t>(1e9 / a.rate_hz)};
    const auto start = std::chrono::steady_clock::now();
    auto next = start;
    std::uint64_t seq = 0;
    while (!g_stop.load())
    {
        if (a.duration_s > 0.0 && std::chrono::steady_clock::now() - start >
                                      std::chrono::duration<double>(a.duration_s))
        {
            break;
        }
        auto sample_result = skeleton.latency_event.Allocate();
        if (!sample_result.has_value())
        {
            std::fprintf(stderr, "vxlola send: allocate failed\n");
            return 1;
        }
        auto sample = std::move(sample_result).value();
        sample->seq = seq;
        sample->size = static_cast<std::uint32_t>(a.size);
        std::memset(sample->payload.data(), static_cast<int>(seq & 0xFFU), a.size);
        sample->t_send_ns = NowNs();
        std::ignore = skeleton.latency_event.Send(std::move(sample));
        ++seq;
        next += period;
        std::this_thread::sleep_until(next);
    }
    skeleton.StopOfferService();
    std::fprintf(stderr, "vxlola send: %llu samples sent\n", static_cast<unsigned long long>(seq));
    return 0;
}

struct Receiver
{
    std::mutex mutex;
    std::condition_variable cv;
    std::vector<std::int64_t> latencies;
    std::size_t seen{0};
    std::uint64_t last_seq{0};
    bool have_last{false};
    std::uint64_t lost{0};
    std::uint64_t checksum{0};
    std::uint32_t size{0};
    bool done{false};
};

std::int64_t Quantile(const std::vector<std::int64_t>& sorted, double q)
{
    const auto i = static_cast<std::size_t>(q * static_cast<double>(sorted.size() - 1) + 0.5);
    return sorted[std::min(i, sorted.size() - 1)];
}

int Recv(const Args& a)
{
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::duration_cast<std::chrono::nanoseconds>(
                                                                 std::chrono::duration<double>(a.timeout_s));
    const auto instance = Instance();
    std::optional<LatencyProxy::HandleType> handle;
    while (!handle.has_value())
    {
        auto found = LatencyProxy::FindService(instance);
        if (!found.has_value())
        {
            std::fprintf(stderr, "vxlola recv: FindService failed\n");
            return 1;
        }
        if (!found.value().empty())
        {
            handle = found.value()[0];
            break;
        }
        if (g_stop.load() || std::chrono::steady_clock::now() > deadline)
        {
            std::fprintf(stderr, "vxlola recv: no sender found\n");
            return 1;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds{1});
    }
    auto proxy_result = LatencyProxy::Create(handle.value());
    if (!proxy_result.has_value())
    {
        std::fprintf(stderr, "vxlola recv: proxy not created\n");
        return 1;
    }
    auto& proxy = proxy_result.value();
    constexpr std::size_t kMaxSamples = 4;
    if (!proxy.latency_event.Subscribe(kMaxSamples).has_value())
    {
        std::fprintf(stderr, "vxlola recv: subscribe failed\n");
        return 1;
    }

    Receiver rx;
    rx.latencies.reserve(a.count);
    auto handler = [&proxy, &rx, &a]() {
        std::ignore = proxy.latency_event.GetNewSamples(
            [&rx, &a](score::mw::com::SamplePtr<LatencySample> sample) noexcept {
                std::uint64_t sum = 0;
                const std::uint32_t size = sample->size;
                for (std::uint32_t i = 0; i < size; i += 64)
                {
                    sum += sample->payload[i];
                }
                const std::int64_t t_recv = NowNs();
                std::lock_guard<std::mutex> lock{rx.mutex};
                if (rx.done)
                {
                    return;
                }
                if (rx.have_last && sample->seq > rx.last_seq + 1 && rx.seen >= a.warmup)
                {
                    rx.lost += sample->seq - rx.last_seq - 1;
                }
                rx.last_seq = sample->seq;
                rx.have_last = true;
                rx.checksum += sum;
                rx.size = size;
                if (++rx.seen > a.warmup)
                {
                    rx.latencies.push_back(t_recv - sample->t_send_ns);
                    if (rx.latencies.size() >= a.count)
                    {
                        rx.done = true;
                        rx.cv.notify_one();
                    }
                }
            },
            kMaxSamples);
    };
    if (!proxy.latency_event.SetReceiveHandler(handler).has_value())
    {
        std::fprintf(stderr, "vxlola recv: receive handler not set\n");
        return 1;
    }
    {
        std::unique_lock<std::mutex> lock{rx.mutex};
        while (!rx.done && !g_stop.load() && std::chrono::steady_clock::now() < deadline)
        {
            rx.cv.wait_for(lock, std::chrono::milliseconds{100});
        }
        rx.done = true;
    }
    std::ignore = proxy.latency_event.UnsetReceiveHandler();
    proxy.latency_event.Unsubscribe();

    std::vector<std::int64_t> v;
    std::uint32_t size = 0;
    {
        std::lock_guard<std::mutex> lock{rx.mutex};
        v = rx.latencies;
        size = rx.size;
    }
    if (v.empty())
    {
        std::fprintf(stderr, "vxlola recv: no samples measured\n");
        return 1;
    }
    std::sort(v.begin(), v.end());
    long double total = 0;
    for (auto x : v)
    {
        total += x;
    }
    std::printf(
        "{\"tool\":\"vxlola\",\"size_bytes\":%zu,\"count\":%zu,\"warmup\":%zu,\"lost\":%llu,\"complete\":%s,"
        "\"latency_ns\":{\"min\":%lld,\"p50\":%lld,\"p90\":%lld,\"p99\":%lld,\"p999\":%lld,\"max\":%lld,"
        "\"mean\":%.0Lf}}\n",
        static_cast<std::size_t>(size), v.size(), a.warmup,
        static_cast<unsigned long long>(rx.lost), v.size() >= a.count ? "true" : "false",
        static_cast<long long>(v.front()), static_cast<long long>(Quantile(v, 0.50)),
        static_cast<long long>(Quantile(v, 0.90)), static_cast<long long>(Quantile(v, 0.99)),
        static_cast<long long>(Quantile(v, 0.999)), static_cast<long long>(v.back()), total / v.size());
    std::fflush(stdout);
    return v.size() >= a.count ? 0 : 1;
}

}  // namespace vxlola

int main(int argc, char** argv)
{
    const auto args = vxlola::Parse(argc, argv);
    std::signal(SIGINT, vxlola::OnSignal);
    std::signal(SIGTERM, vxlola::OnSignal);
    score::mw::com::runtime::InitializeRuntime(score::mw::com::runtime::RuntimeConfiguration(args.config));
    return args.role == "send" ? vxlola::Send(args) : vxlola::Recv(args);
}
