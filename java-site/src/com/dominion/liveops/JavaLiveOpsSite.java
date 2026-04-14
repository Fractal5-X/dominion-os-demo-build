package com.dominion.liveops;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.OutputStream;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.lang.management.MemoryUsage;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicLong;

public final class JavaLiveOpsSite {
    private static final String SERVICE_NAME = "dominion-java-live-ops-site";
    private static final String VERSION = "1.0.0";
    private static final Instant STARTED_AT = Instant.now();
    private static final AtomicLong REQUEST_SEQUENCE = new AtomicLong(0);
    private static final ConcurrentHashMap<String, AtomicLong> REQUESTS_BY_PATH = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, AtomicLong> REQUESTS_BY_PATH_AND_STATUS = new ConcurrentHashMap<>();

    private JavaLiveOpsSite() {
    }

    public static void main(String[] args) throws IOException {
        int port = envPort("JAVA_SITE_PORT", envPort("PORT", 8090));
        int workerThreads = Math.max(4, Runtime.getRuntime().availableProcessors() * 2);

        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.createContext("/", new RootHandler());
        server.createContext("/health", new JsonHandler("health", false));
        server.createContext("/healthz", new JsonHandler("health", false));
        server.createContext("/ready", new JsonHandler("ready", true));
        server.createContext("/metrics", new MetricsHandler());
        server.createContext("/api/v1/topology", new TopologyHandler());
        server.setExecutor(Executors.newFixedThreadPool(workerThreads));
        server.start();

        System.out.printf(
            Locale.ROOT,
            "[%s] %s started on port %d with %d workers%n",
            Instant.now(),
            SERVICE_NAME,
            port,
            workerThreads
        );

        try {
            new CountDownLatch(1).await();
        } catch (InterruptedException interruptedException) {
            Thread.currentThread().interrupt();
        }
    }

    private static int envPort(String name, int fallback) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) {
            return fallback;
        }

        try {
            int parsed = Integer.parseInt(value.trim());
            if (parsed < 1 || parsed > 65535) {
                return fallback;
            }
            return parsed;
        } catch (NumberFormatException ex) {
            return fallback;
        }
    }

    private static String envOrDefault(String key, String fallback) {
        String value = System.getenv(key);
        if (value == null || value.isBlank()) {
            return fallback;
        }
        return value.trim();
    }

    private static long uptimeSeconds() {
        return Math.max(1L, Instant.now().getEpochSecond() - STARTED_AT.getEpochSecond());
    }

    private static void record(String path, int status) {
        REQUEST_SEQUENCE.incrementAndGet();
        REQUESTS_BY_PATH.computeIfAbsent(path, ignored -> new AtomicLong()).incrementAndGet();
        REQUESTS_BY_PATH_AND_STATUS
            .computeIfAbsent(path + "|" + status, ignored -> new AtomicLong())
            .incrementAndGet();
    }

    private static void respondJson(HttpExchange exchange, int statusCode, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        exchange.getResponseHeaders().set("Cache-Control", "no-store");
        exchange.sendResponseHeaders(statusCode, bytes.length);
        try (OutputStream output = exchange.getResponseBody()) {
            output.write(bytes);
        } finally {
            record(exchange.getRequestURI().getPath(), statusCode);
        }
    }

    private static void respondHtml(HttpExchange exchange, int statusCode, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "text/html; charset=utf-8");
        exchange.getResponseHeaders().set("Cache-Control", "no-store");
        exchange.sendResponseHeaders(statusCode, bytes.length);
        try (OutputStream output = exchange.getResponseBody()) {
            output.write(bytes);
        } finally {
            record(exchange.getRequestURI().getPath(), statusCode);
        }
    }

    private static final class RootHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            String path = exchange.getRequestURI().getPath();
            if (!Objects.equals(path, "/")) {
                respondJson(
                    exchange,
                    404,
                    "{\"status\":\"not_found\",\"service\":\"" + SERVICE_NAME + "\",\"path\":\"" + escapeJson(path) + "\"}"
                );
                return;
            }

            String html = """
                <!DOCTYPE html>
                <html lang=\"en\">
                <head>
                  <meta charset=\"UTF-8\" />
                  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
                  <title>Dominion Java Live Ops Site</title>
                  <style>
                    :root { color-scheme: light; }
                    body {
                      margin: 0;
                      padding: 2.5rem 1.25rem;
                      font-family: \"IBM Plex Sans\", \"Segoe UI\", sans-serif;
                      color: #0f172a;
                      background:
                        radial-gradient(circle at 10% 0%, rgba(148, 163, 184, 0.25), transparent 35%),
                        linear-gradient(140deg, #f8fafc, #e2e8f0);
                    }
                    main {
                      max-width: 960px;
                      margin: 0 auto;
                      background: rgba(255, 255, 255, 0.9);
                      border: 1px solid #d8dee8;
                      border-radius: 20px;
                      padding: 2rem;
                      box-shadow: 0 18px 44px rgba(15, 23, 42, 0.1);
                    }
                    h1 { margin-top: 0; font-size: clamp(1.9rem, 3.7vw, 3rem); }
                    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); gap: 0.75rem; }
                    .card { border: 1px solid #e2e8f0; background: #f8fafc; border-radius: 12px; padding: 0.9rem; }
                    code { background: #e2e8f0; padding: 0.12rem 0.32rem; border-radius: 6px; }
                  </style>
                </head>
                <body>
                  <main>
                    <h1>Dominion Java Live Ops Site</h1>
                    <p>Optimized Java 17 service for sovereign local operations and command-center topology integration.</p>
                    <div class=\"grid\" style=\"margin-top: 1.1rem;\">
                      <div class=\"card\"><strong>Service</strong><br/><code>%s</code></div>
                      <div class=\"card\"><strong>Version</strong><br/><code>%s</code></div>
                      <div class=\"card\"><strong>Uptime</strong><br/><code>%d seconds</code></div>
                      <div class=\"card\"><strong>Requests</strong><br/><code>%d total</code></div>
                    </div>
                    <p style=\"margin-top: 1rem;\">Routes: <code>/health</code>, <code>/ready</code>, <code>/metrics</code>, <code>/api/v1/topology</code>.</p>
                  </main>
                </body>
                </html>
                """.formatted(
                SERVICE_NAME,
                VERSION,
                uptimeSeconds(),
                REQUEST_SEQUENCE.get()
            );

            respondHtml(exchange, 200, html);
        }
    }

    private static final class JsonHandler implements HttpHandler {
        private final String endpoint;
        private final boolean includeReady;

        private JsonHandler(String endpoint, boolean includeReady) {
            this.endpoint = endpoint;
            this.includeReady = includeReady;
        }

        @Override
        public void handle(HttpExchange exchange) throws IOException {
            String body;
            if (includeReady) {
                body = "{"
                    + "\"status\":\"healthy\","
                    + "\"ready\":true,"
                    + "\"endpoint\":\"" + endpoint + "\","
                    + "\"service\":\"" + SERVICE_NAME + "\","
                    + "\"version\":\"" + VERSION + "\","
                    + "\"timestamp\":\"" + Instant.now() + "\""
                    + "}";
            } else {
                body = "{"
                    + "\"status\":\"healthy\","
                    + "\"endpoint\":\"" + endpoint + "\","
                    + "\"service\":\"" + SERVICE_NAME + "\","
                    + "\"version\":\"" + VERSION + "\","
                    + "\"timestamp\":\"" + Instant.now() + "\""
                    + "}";
            }
            respondJson(exchange, 200, body);
        }
    }

    private static final class TopologyHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            String commandCenter = envOrDefault("COMMAND_CENTER_URL", "http://127.0.0.1:5000");
            String billing = envOrDefault("BILLING_URL", "http://127.0.0.1:5001");
            String commandCore = envOrDefault("COMMAND_CORE_URL", "http://127.0.0.1:5002");
            String oauth = envOrDefault("OAUTH_SERVER_URL", "http://127.0.0.1:8080");
            String widget = envOrDefault("ASKPHI_WIDGET_URL", "http://127.0.0.1:8081");

            String body = "{"
                + "\"status\":\"healthy\","
                + "\"service\":\"" + SERVICE_NAME + "\","
                + "\"timestamp\":\"" + Instant.now() + "\","
                + "\"topology\":{"
                + "\"command_center\":\"" + escapeJson(commandCenter) + "\","
                + "\"billing\":\"" + escapeJson(billing) + "\","
                + "\"command_core\":\"" + escapeJson(commandCore) + "\","
                + "\"oauth\":\"" + escapeJson(oauth) + "\","
                + "\"widget\":\"" + escapeJson(widget) + "\""
                + "}"
                + "}";

            respondJson(exchange, 200, body);
        }
    }

    private static final class MetricsHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            List<String> lines = new ArrayList<>();

            MemoryMXBean memoryMXBean = ManagementFactory.getMemoryMXBean();
            MemoryUsage heap = memoryMXBean.getHeapMemoryUsage();

            lines.add("# HELP dominion_java_site_uptime_seconds Uptime in seconds.");
            lines.add("# TYPE dominion_java_site_uptime_seconds gauge");
            lines.add("dominion_java_site_uptime_seconds " + uptimeSeconds());

            lines.add("# HELP dominion_java_site_requests_total Total HTTP requests handled.");
            lines.add("# TYPE dominion_java_site_requests_total counter");
            lines.add("dominion_java_site_requests_total " + REQUEST_SEQUENCE.get());

            lines.add("# HELP dominion_java_site_heap_used_bytes JVM heap used bytes.");
            lines.add("# TYPE dominion_java_site_heap_used_bytes gauge");
            lines.add("dominion_java_site_heap_used_bytes " + heap.getUsed());

            lines.add("# HELP dominion_java_site_heap_max_bytes JVM heap max bytes.");
            lines.add("# TYPE dominion_java_site_heap_max_bytes gauge");
            lines.add("dominion_java_site_heap_max_bytes " + heap.getMax());

            lines.add("# HELP dominion_java_site_requests_by_path_total Requests by path.");
            lines.add("# TYPE dominion_java_site_requests_by_path_total counter");
            REQUESTS_BY_PATH.entrySet()
                .stream()
                .sorted(Comparator.comparing(Map.Entry::getKey))
                .forEach(entry -> lines.add(
                    "dominion_java_site_requests_by_path_total{path=\""
                    + escapeMetricLabel(entry.getKey())
                    + "\"} "
                    + entry.getValue().get()
                ));

            lines.add("# HELP dominion_java_site_requests_by_path_and_status_total Requests by path and status code.");
            lines.add("# TYPE dominion_java_site_requests_by_path_and_status_total counter");
            REQUESTS_BY_PATH_AND_STATUS.entrySet()
                .stream()
                .sorted(Comparator.comparing(Map.Entry::getKey))
                .forEach(entry -> {
                    String[] parts = entry.getKey().split("\\|", 2);
                    String path = parts.length > 0 ? parts[0] : "unknown";
                    String status = parts.length > 1 ? parts[1] : "0";
                    lines.add(
                        "dominion_java_site_requests_by_path_and_status_total{path=\""
                            + escapeMetricLabel(path)
                            + "\",status=\""
                            + escapeMetricLabel(status)
                            + "\"} "
                            + entry.getValue().get()
                    );
                });

            String body = String.join("\n", lines) + "\n";
            byte[] bytes = body.getBytes(StandardCharsets.UTF_8);

            exchange.getResponseHeaders().set("Content-Type", "text/plain; version=0.0.4; charset=utf-8");
            exchange.getResponseHeaders().set("Cache-Control", "no-store");
            exchange.sendResponseHeaders(200, bytes.length);
            try (OutputStream output = exchange.getResponseBody()) {
                output.write(bytes);
            } finally {
                record(exchange.getRequestURI().getPath(), 200);
            }
        }
    }

    private static String escapeJson(String value) {
        return value
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r");
    }

    private static String escapeMetricLabel(String value) {
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
