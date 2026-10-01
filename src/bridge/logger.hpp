#pragma once

#include <cstdio>
#include <cstdarg>
#include <cstdint>
#include <cstring>
#include <chrono>
#include <string>
#include <vector>
#include <mutex>
#include <atomic>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

enum BridgeLogLevel {
    BRIDGE_LOG_OFF = 0,
    BRIDGE_LOG_ERROR = 1,
    BRIDGE_LOG_WARN = 2,
    BRIDGE_LOG_INFO = 3,
    BRIDGE_LOG_DEBUG = 4,
    BRIDGE_LOG_TRACE = 5,
    BRIDGE_LOG_INTERNAL = 6
};

class BridgeLogger {
private:
    FILE *m_file = nullptr;
    std::mutex m_mutex;
    static const size_t RING_CAPACITY = 200;
    std::vector<std::string> m_ring_buffer;
    size_t m_ring_head = 0;
    size_t m_ring_count = 0;
    int m_min_level = BRIDGE_LOG_TRACE;
    std::atomic<bool> m_initialized{false};

    BridgeLogger() {
        m_ring_buffer.resize(RING_CAPACITY);
    }

    ~BridgeLogger() {
        close();
    }

public:
    static BridgeLogger& instance() {
        static BridgeLogger s_inst;
        return s_inst;
    }

    void init(const char *log_path = nullptr) {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_file) return;

        const char *target = log_path;
        if (!target) {
            target = getenv("LAPIS_BRIDGE_LOG");
        }
        if (!target) {
            target = getenv("LAPIS_LOG_FILE");
        }
        if (!target) {
            // Default bridge log path in standard project structure
            target = "log/bridge.log";
        }

#ifdef _WIN32
        CreateDirectoryA("log", NULL);
#endif
        m_file = fopen(target, "a");
        m_initialized.store(true);
    }

    void set_min_level(int level) {
        m_min_level = level;
    }

    int get_min_level() const {
        return m_min_level;
    }

    static const char* level_name(int level) {
        switch (level) {
            case BRIDGE_LOG_ERROR:    return "ERROR";
            case BRIDGE_LOG_WARN:     return "WARN";
            case BRIDGE_LOG_INFO:     return "INFO";
            case BRIDGE_LOG_DEBUG:    return "DEBUG";
            case BRIDGE_LOG_TRACE:    return "TRACE";
            case BRIDGE_LOG_INTERNAL: return "INTERNAL";
            default:                  return "UNKNOWN";
        }
    }

    void log_v(int level, const char *channel, const char *fmt, va_list args) {
        if (level > m_min_level || level <= BRIDGE_LOG_OFF) return;

        // Auto-initialize if not yet explicitly done
        if (!m_initialized.load()) {
            init();
        }

        // Format timestamp: HH:MM:SS.mmm
        auto now = std::chrono::system_clock::now();
        auto now_ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;
        auto timer = std::chrono::system_clock::to_time_t(now);
        std::tm bt{};
#ifdef _WIN32
        localtime_s(&bt, &timer);
#else
        localtime_r(&timer, &bt);
#endif

        char time_str[32];
        snprintf(time_str, sizeof(time_str), "%02d:%02d:%02d.%03d",
                 bt.tm_hour, bt.tm_min, bt.tm_sec, (int)now_ms.count());

        char msg_buf[2048];
        vsnprintf(msg_buf, sizeof(msg_buf), fmt, args);

        char line_buf[2560];
        snprintf(line_buf, sizeof(line_buf), "[%s] [%s] [%s] %s",
                 time_str, level_name(level), channel ? channel : "Bridge", msg_buf);

        std::lock_guard<std::mutex> lock(m_mutex);

        // 1. Store in circular ring buffer for crash diagnostics
        m_ring_buffer[m_ring_head] = line_buf;
        m_ring_head = (m_ring_head + 1) % RING_CAPACITY;
        if (m_ring_count < RING_CAPACITY) {
            m_ring_count++;
        }

        // 2. Persist to file sink if available
        if (m_file) {
            fputs(line_buf, m_file);
            fputc('\n', m_file);
            if (level <= BRIDGE_LOG_WARN) {
                fflush(m_file);
            }
        }
    }

    void log(int level, const char *channel, const char *fmt, ...) {
        va_list args;
        va_start(args, fmt);
        log_v(level, channel, fmt, args);
        va_end(args);
    }

    void dump_ring_buffer(FILE *out) {
        if (!out) return;
        std::lock_guard<std::mutex> lock(m_mutex);
        fputs("\n--- Last In-Flight Diagnostic Messages (Pre-Crash Ring Buffer) ---\n", out);
        if (m_ring_count == 0) {
            fputs("  (no recorded messages)\n", out);
            return;
        }

        size_t start = (m_ring_count < RING_CAPACITY) ? 0 : m_ring_head;
        for (size_t i = 0; i < m_ring_count; ++i) {
            size_t idx = (start + i) % RING_CAPACITY;
            fputs("  ", out);
            fputs(m_ring_buffer[idx].c_str(), out);
            fputc('\n', out);
        }
        fputs("------------------------------------------------------------------\n", out);
        fflush(out);
    }

    void flush() {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_file) fflush(m_file);
    }

    void close() {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_file) {
            fclose(m_file);
            m_file = nullptr;
        }
    }
};

inline void bridge_log(int level, const char *channel, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    BridgeLogger::instance().log_v(level, channel, fmt, args);
    va_end(args);
}
