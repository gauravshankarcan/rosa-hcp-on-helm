# helm/charts/

Feature charts installed on **spoke** clusters after Argo is instantiated.

| Chart | Survey flag | How enable is applied |
| --- | --- | --- |
| `karpenter/` | `karpenter` | Argo Application sets root Helm `enabled: true` (chart gates on `.Values.enabled`) |
| `amq-streams/` | `amq-stream` | Same — root `enabled: true` via Application `helm.values` |

Applications are only generated when the survey flag is selected, so unselected features stay absent.

## Values philosophy

- Chart `values.yaml` is **detailed** (nested knobs + root `enabled: false` by default).
- Cluster override `<cluster>/base-configs/base-values.yaml` is **thin** (shared deltas such as `workers.count`).
- Feature **on/off** is owned by the Argo Application (inline `enabled: true`), not nested keys in the shared valueFile.

Empty feature flag selection → no feature Applications → charts not installed.
