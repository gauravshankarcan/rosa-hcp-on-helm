# helm/charts/

Feature charts installed on **spoke** clusters after Argo is instantiated.

| Chart | Survey flag | Enable key |
| --- | --- | --- |
| `karpenter/` | `karpenter` | `karpenter.enabled` |
| `amq-streams/` | `amq-stream` | `amqStreams.enabled` |

## Values philosophy

- Chart `values.yaml` is **detailed** (nested knobs + component enables).
- Cluster override `<cluster>/base-configs/base-values.yaml` is **thin** (survey deltas only).

Empty feature flag selection → charts remain disabled (`enabled: false`).
