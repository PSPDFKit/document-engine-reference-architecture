# Document Engine example - Identifying clients in Document Engine logs

- [About this example](#about-this-example)
- [How it works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Reading the output](#reading-the-output)
- [Following one annotation](#following-one-annotation)
- [Common rejection reasons](#common-rejection-reasons)
- [Using this in your own cluster](#using-this-in-your-own-cluster)
- [What this doesn't show](#what-this-doesnt-show)
- [Cleaning up](#cleaning-up)
- [Support](#support)
- [License](#license)
- [Contributing](#contributing)

> This example shows how to tell which client - iOS, Android or Web, and which SDK version - sent each request to [Nutrient Document Engine](https://www.nutrient.io/guides/document-engine/), and what Document Engine did with it. That makes client-dependent issues, such as annotations that disappear only on one platform, much easier to debug.

## About this example

When the same Document Engine serves an iOS app and a Web app, its logs alone don't tell you which app a request came from. Every Nutrient SDK identifies itself on every request, though, and the proxy in front of Document Engine can record that.

This example installs Document Engine behind [Envoy Gateway](https://gateway.envoyproxy.io/) on any Kubernetes cluster, and adds:

- **An access log that identifies the client.** Envoy writes one JSON line per request, including the `PSPDFKit-Platform` and `PSPDFKit-Version` headers every SDK sends.
- **A shared request ID.** Envoy generates an `X-Request-Id` for every request and forwards it. Document Engine uses it as its own `request_id`, so its log lines for that request can be matched to the access log line.
- **`trace-clients.sh`**, which joins the two logs and shows, for every Instant sync request, which client sent it and what Document Engine accepted and rejected - or, with `--record`, every change to one annotation, from every client.
- **A one-page Web SDK viewer** and **`simulate-clients.sh`**, which plays an iOS and a Web client against the same annotation, including a conflict and a rejection.

It builds on [`../de-orbstack-kubernetes`](../de-orbstack-kubernetes/), but works on any local cluster: [kind](https://kind.sigs.k8s.io/), [minikube](https://minikube.sigs.k8s.io/), OrbStack or Docker Desktop.

## How it works

```
 iOS app ─┐                     ┌─ access log: platform, SDK version, user agent, status,
          ├─► Envoy Gateway ────┤  duration, request ID
 Web app ─┘   (X-Request-Id)    │
                    │           └──────────────────────┐
                    ▼                                  │  joined by request ID
             Document Engine ── log: request_id, ──────┘  (trace-clients.sh)
                                accepted and rejected changes
```

Every Nutrient SDK sends these headers on every request to Document Engine:

| Header | Example | Meaning |
| --- | --- | --- |
| `PSPDFKit-Platform` | `ios`, `android`, `web` | Which SDK sent the request |
| `PSPDFKit-Version` | `protocol=5, client=1.22.0, client-git=663789431d` | SDK version, and the Instant protocol it speaks |
| `User-Agent` | Your app's or the browser's | Usually identifies your app and its version |

Two kinds of requests don't carry the `PSPDFKit-*` headers, because browsers don't let JavaScript add headers to them: CORS preflight (`OPTIONS`) requests, and the WebSocket connection at `/i/d/:document_id/websocket`, which Instant uses to show who else has the document open. For those, `platform` and `sdk_version` are empty, and the user agent is the only hint.

Document Engine reads the headers, but doesn't write them to its own logs. The files in this example that make the difference:

- [`gateway.yaml`](./gateway.yaml) - the `EnvoyProxy` with the JSON access log format, and a `BackendTrafficPolicy` that raises Envoy's default 15 second route timeout. Without it, Envoy ends Instant's long-poll sync requests early, and clients see `504` errors.
- [`document-engine.values.yaml`](./document-engine.values.yaml) - turns on the chart's Gateway API support, structured (JSON) logging, and `debug` logging, which adds the IDs and reasons of rejected changes.

## Prerequisites

- A local Kubernetes cluster, for example `kind create cluster --name de-client-tracing`
- [kubectl](https://kubernetes.io/docs/tasks/tools/), [Helm](https://helm.sh/docs/intro/install/), [jq](https://jqlang.org/), OpenSSL, curl and Python 3

On macOS:

```shell
brew install kubectl helm jq kind
```

## Getting started

1. Clone this repository and navigate to the example directory:

```shell
git clone https://github.com/PSPDFKit/document-engine-reference-architecture.git
cd document-engine-reference-architecture/examples/de-client-tracing
```

2. Run the setup script. It installs into the cluster of your current kubectl context; set `KUBE_CONTEXT` to pick another one:

```shell
KUBE_CONTEXT=kind-de-client-tracing ./setup.sh
```

This takes about five minutes. It installs CloudNative-PG, Envoy Gateway and Document Engine, creates a key pair for signing JWTs in `keys/`, and uploads a sample document.

3. Make Document Engine reachable on `http://localhost:8080`, and serve the viewer page on `http://localhost:4300`. Run each in its own terminal; `setup.sh` prints the exact port-forward command for your cluster:

```shell
kubectl --context kind-de-client-tracing port-forward -n envoy-gateway-system \
  service/$(kubectl --context kind-de-client-tracing get service -n envoy-gateway-system \
    -l gateway.envoyproxy.io/owning-gateway-name=document-engine -o jsonpath='{.items[0].metadata.name}') 8080:80

python3 -m http.server 4300 --directory viewer
```

4. Open two viewers, as two different users, and add or move a few annotations:

- http://localhost:4300/?user=alice
- http://localhost:4300/?user=bob

The tokens `setup.sh` writes are valid for an hour. To create a new one, or one for another user, run `./mint-jwt.sh --write client-tracing-demo <user-id> <name>` and open `?user=<user-id>`.

5. Add a simulated iOS client and Web client, which change the same annotation in turn:

```shell
./simulate-clients.sh
```

6. See which client sent each sync request, and what Document Engine did with it:

```shell
KUBE_CONTEXT=kind-de-client-tracing ./trace-clients.sh --since 30m
```

## Reading the output

```
TIME                     PLATFORM SDK     STATUS USER   DURATION ACCEPTED REJECTED RECEIVED REQUEST ID / REJECTED RECORDS
2026-10-16T18:12:44.065Z web      1.22.0  200    Alice  27ms     1        0        n/a      168d09a9-ed03-4b95-91c7-7d65a7a82b2a
2026-10-16T18:12:44.095Z web      1.22.0  200    -      30009ms  -        -        -        ea3649b8-da80-4216-910b-4a9fd3dabc91
2026-10-16T18:21:21.749Z ios      27.0.1  200    Carol  13ms     0        1        n/a      77f1669b-2303-4967-9e4f-2da282d7b69e
                                                                                            01M3TEST… (updated): Forbidden creator name
```

| Column | Meaning |
| --- | --- |
| `PLATFORM`, `SDK` | From the `PSPDFKit-Platform` and `PSPDFKit-Version` headers |
| `STATUS` | The HTTP status the client received. Errors from the proxy, such as `413` for a request over the size limit or `504` for a timeout, appear here even though Document Engine never processed the request |
| `USER` | The creator name from the client's JWT. Document Engine only logs it for syncs that carry changes, at `debug` level |
| `DURATION` | Saves take tens of milliseconds. A sync with nothing to send is a long poll: it waits up to about 30 seconds for other clients' changes, and ends early when one arrives |
| `ACCEPTED`, `REJECTED` | The changes this client sent, and what Document Engine did with them. `-` means the client sent no changes. `no log` means Document Engine has no log for the request: it failed before Document Engine processed it, or the container that handled it has restarted since, and `kubectl logs` no longer has its logs |
| `RECEIVED` | For syncs that sent nothing: whether the response delivered other clients' changes, estimated from the response size |

Rejected changes are listed under their sync request, with the annotation ID, what the client tried to do, and Document Engine's reason.

The raw logs are available too:

```shell
# One JSON line per request, with platform, sdk_version, user_agent and request_id
kubectl --context kind-de-client-tracing logs -n envoy-gateway-system -f \
  -l gateway.envoyproxy.io/owning-gateway-name=document-engine -c envoy

# Document Engine's structured log; find one request with grep <request-id>
kubectl --context kind-de-client-tracing logs -n document-engine -f deploy/document-engine
```

## Following one annotation

When a user reports that an annotation disappeared or changed, the question is usually who changed it, from which client, and whether Document Engine accepted it. `--record` answers that for one annotation:

```shell
KUBE_CONTEXT=kind-de-client-tracing ./trace-clients.sh --since 1h --record DF4169ABCA77741E14EF168D6D
```

```
TIME                     PLATFORM SDK     USER   ACTION   OUTCOME   REASON / REQUEST ID
2026-10-16T18:27:23.336Z ios      27.0.1  Carol  created  accepted  caa87fb2-968b-4dc8-96ca-017d27e56b6e
2026-10-16T18:27:24.424Z web      1.22.0  Dave   updated  accepted  7dbce339-b3e5-43ab-aa6d-186f47f6b927
2026-10-16T18:27:25.473Z ios      27.0.1  Carol  updated  rejected  conflict (c84dfb5e-2b0e-4c4d-9430-8b0e254f40d2)
2026-10-16T18:27:27.628Z ios      27.0.1  Carol  deleted  accepted  f92781d9-24b4-4037-a1c6-cebe287193b3
```

To find an annotation's ID in the Web SDK, call `instance.getAnnotations(pageIndex)` in the browser console and read `id`.

## Common rejection reasons

When Document Engine rejects a change, the server's version is kept, and the SDK rolls the change back on that device: a rejected new annotation is removed, and a rejected edit or deletion is reverted to the server's version. Depending on the SDK and its version, a rejected edit may only be reverted on screen after the document is reloaded.

| Reason | What it means |
| --- | --- |
| `conflict` | The client edited or deleted an annotation that changed on the server after the client last synced. The server's version is kept. |
| `Forbidden creator name` | The JWT sets `creator_name`, and the change doesn't match it: a new annotation must carry that creator name, and an edit can't change an annotation's existing creator name. |
| `Editing this record is not allowed under current collaboration permissions …` (also `Deleting …`, `Setting this record's group …`) | The JWT's [collaboration permissions](https://www.nutrient.io/guides/document-engine/instant-synchronization/permissions/overview/) don't allow this change. |
| `Root annotation doesn't exist` (and other `Root annotation …` reasons) | A comment refers to an annotation that doesn't exist on the server, for example because it was deleted or itself rejected. |
| `attachment_not_found` | The change refers to an attachment, such as an image, that wasn't uploaded with it. |

## Using this in your own cluster

The parts to carry over are the access log format, the request ID, and a log pipeline that keeps both logs searchable:

- **Envoy Gateway or Istio**: use the `EnvoyProxy` access log from [`gateway.yaml`](./gateway.yaml). Envoy generates and forwards `x-request-id` by default.
- **Other proxies**: log the `PSPDFKit-Platform`, `PSPDFKit-Version` and `User-Agent` request headers, and generate an `X-Request-Id` that you also forward to Document Engine. It needs to be between 20 and 200 characters long. For example, NGINX can log `$http_pspdfkit_platform` and `$http_pspdfkit_version`, and forward `$request_id`.
- **AWS Application Load Balancer**: ALB access logs include the user agent, but not custom request headers, and ALB doesn't forward an `X-Request-Id`. Put a proxy such as Envoy Gateway behind the load balancer, or correlate by time and path.
- **Log pipelines**: `kubectl logs`, which `trace-clients.sh` uses, only keeps the logs of a pod's current and previous container, so the logs of a pod that restarted several times are lost. In your own cluster, collect both logs with a log pipeline. Both logs are one JSON object per line, so the OpenTelemetry Collector, Fluent Bit, Vector, Grafana Alloy, or your cloud provider's agent can parse them into fields without custom parsing. The join is then a query on `request_id` (access log) and `meta.request_id` (Document Engine).
- **Timeouts**: keep the proxy's request timeout above Document Engine's `SERVER_REQUEST_TIMEOUT` (`config.requestTimeoutSeconds` in the Helm chart), so long-poll sync requests end normally instead of with a proxy error.

## What this doesn't show

This example shows what Document Engine did with each request. Some client issues never reach the server, and some details depend on `debug` logging:

- **Changes that are never sent.** Changes lost while a device is offline, or when a viewer is closed before it syncs, only show on the device. Log sync errors and rejections in your app too: on iOS through the SDK's log handler and `instantClient(_:documentDescriptor:didFailSyncWithError:)`, and on Web through `instance.ensureChangesSaved()` and the `document.saveStateChange` event. Include the annotation ID, so you can find the same change in Document Engine's logs.
- **Which device or session sent an idle sync.** Document Engine only logs the user for syncs that carry changes. If you need to tell sessions apart, log a session ID in your app alongside the time of each sync.
- **`debug` logging in production.** Rejected annotation IDs, reasons and the user come from Document Engine's `debug` output, which is verbose and costs performance. At `info`, you still get the accepted and rejected counts for each sync. Turn on `debug` while you investigate, not permanently.
- **Large changes.** Document Engine's `debug` output shortens long collections, so for large annotations, such as long ink strokes, or syncs with many changes, some fields and annotation IDs may be cut off as `...`.

## Cleaning up

```shell
kind delete cluster --name de-client-tracing
```

## Support

Nutrient offers support for customers with an active SDK license via [Nutrient Support](https://www.nutrient.io/support/request/).

Are you [evaluating our SDK](https://www.nutrient.io/sdk/try)? That's great, we're happy to help out! To make sure this is fast, please use a work email and have someone from your company fill out our [sales form](https://www.nutrient.io/contact-sales/).

## License

This project is licensed under the BSD license. See the LICENSE file for more details.

## Contributing

Please ensure you have signed our CLA so that we can accept your contributions.
