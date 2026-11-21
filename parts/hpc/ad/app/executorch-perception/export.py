"""Export a torchvision classifier to an ExecuTorch program lowered to XNNPACK.

Runs once, at image build time. The weights are random (seed 0), not trained: the part measures
inference cost, which depends on the graph and the input shape, not on the weight values.

    python3 -I export.py <model> <out.pte>
"""

import sys

import torch
import torchvision
from executorch.backends.xnnpack.partition.xnnpack_partitioner import XnnpackPartitioner
from executorch.devtools.backend_debug import get_delegation_info
from executorch.exir import to_edge_transform_and_lower

MODELS = ("mobilenet_v2", "resnet18")
INPUT_SHAPE = (1, 3, 224, 224)


def main() -> None:
    name, out = sys.argv[1], sys.argv[2]
    if name not in MODELS:
        sys.exit(f"unknown model {name!r}; one of {', '.join(MODELS)}")
    torch.manual_seed(0)
    model = getattr(torchvision.models, name)(weights=None).eval()
    example = (torch.randn(*INPUT_SHAPE),)
    edge = to_edge_transform_and_lower(
        torch.export.export(model, example), partitioner=[XnnpackPartitioner()]
    )
    info = get_delegation_info(edge.exported_program().graph_module)
    # Everything but the graph's output plumbing must run on XNNPACK; a model that falls back
    # to portable kernels would time the reference operators instead.
    if info.num_non_delegated_nodes > 1:
        sys.exit(f"{name}: {info.num_non_delegated_nodes} nodes not delegated to XNNPACK")
    with open(out, "wb") as f:
        f.write(edge.to_executorch().buffer)
    print(f"{name}: {info.num_delegated_nodes} nodes delegated to XNNPACK")


if __name__ == "__main__":
    main()
