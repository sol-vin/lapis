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
    std::string m_log_path;
    size_t m_bytes_written = 0;
    std::mutex m_mutex;
    static const size_t RING_CAPACITY = 200;
    static const size_t MAX_LOG_BYTES = 10 * 1024 * 1024; // 10 MB rotation cap
    std::vector<std::string> m_ring_buffer;
    size_t m_ring_head = 0;
    size_t m_ring_count = 0;
    int m_min_level = BRIDGE_LOG_TRACE;
    int m_file_min_level = BRIDGE_LOG_INFO;
    std::atomic<bool> m_initialized{false};

    BridgeLogger() {
        m_ring_buffer.resize(RING_CAPACITY);
    }

    ~BridgeLogger() {
        close();
    }

    static int parse_level_str(const char *str, int fallback) {
        if (!str || !str[0]) return fallback;
        if (_stricmp_ascii(str, "OFF") == 0 || strcmp(str, "0") == 0) return BRIDGE_LOG_OFF;
        if (_stricmp_ascii(str, "ERROR") == 0 || strcmp(str, "1") == 0) return BRIDGE_LOG_ERROR;
        if (_stricmp_ascii(str, "WARN") == 0 || _stricmp_ascii(str, "WARNING") == 0 || strcmp(str, "2") == 0) return BRIDGE_LOG_WARN;
        if (_stricmp_ascii(str, "INFO") == 0 || strcmp(str, "3") == 0) return BRIDGE_LOG_INFO;
        if (_stricmp_ascii(str, "DEBUG") == 0 || strcmp(str, "4") == 0) return BRIDGE_LOG_DEBUG;
        if (_stricmp_ascii(str, "TRACE") == 0 || strcmp(str, "5") == 0) return BRIDGE_LOG_TRACE;
        if (_stricmp_ascii(str, "INTERNAL") == 0 || strcmp(str, "6") == 0) return BRIDGE_LOG_INTERNAL;
        return fallback;
    }

    static int _stricmp_ascii(const char *a, const char *b) {
        while (*a && *b) {
            char ca = (*a >= 'a' && *a <= 'z') ? (*a - 32) : *a;
            char cb = (*b >= 'a' && *b <= 'z') ? (*b - 32) : *b;
            if (ca != cb) return (int)(unsigned char)ca - (int)(unsigned char)cb;
            ++a;
            ++b;
        }
        return (int)(unsigned char)*a - (int)(unsigned char)*b;
    }

    void rotate_locked() {
        if (m_file) {
            fclose(m_file);
            m_file = nullptr;
        }
        if (m_log_path.empty()) return;
        std::string rotated = m_log_path + ".1";
        remove(rotated.c_str());
        rename(m_log_path.c_str(), rotated.c_str());
        m_bytes_written = 0;
        m_file = fopen(m_log_path.c_str(), "ab");
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
        m_log_path = target;

        // Configure file log threshold (ring buffer always retains up to TRACE for crash dumps)
        const char *v_bridge = getenv("LAPIS_BRIDGE_VERBOSE");
        const char *v_lib = getenv("LIBGODOT_VERBOSE");
        const char *v_gd = getenv("GODOT_VERBOSE");
        if ((v_bridge && (strcmp(v_bridge, "1") == 0 || _stricmp_ascii(v_bridge, "true") == 0)) ||
            (v_lib && (strcmp(v_lib, "1") == 0 || _stricmp_ascii(v_lib, "true") == 0)) ||
            (v_gd && (strcmp(v_gd, "1") == 0 || _stricmp_ascii(v_gd, "true") == 0))) {
            m_file_min_level = BRIDGE_LOG_TRACE;
        }
        const char *lvl_env = getenv("LAPIS_BRIDGE_LOG_LEVEL");
        if (!lvl_env) lvl_env = getenv("LAPIS_LOG_LEVEL");
        if (lvl_env) {
            m_file_min_level = parse_level_str(lvl_env, m_file_min_level);
        }

#ifdef _WIN32
        CreateDirectoryA("log", NULL);
#endif
        FILE *probe = fopen(target, "rb");
        if (probe) {
            if (fseek(probe, 0, SEEK_END) == 0) {
                long sz = ftell(probe);
                if (sz > 0) m_bytes_written = (size_t)sz;
            }
            fclose(probe);
        }
        if (m_bytes_written >= MAX_LOG_BYTES) {
            rotate_locked();
        } else {
            m_file = fopen(target, "ab");
        }
        m_initialized.store(true);
    }

    void set_min_level(int level) {
        m_min_level = level;
        m_file_min_level = level;
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
        int line_len = snprintf(line_buf, sizeof(line_buf) - 2, "[%s] [%s] [%s] %s",
                                time_str, level_name(level), channel ? channel : "Bridge", msg_buf);
        if (line_len < 0) line_len = 0;
        if ((size_t)line_len >= sizeof(line_buf) - 2) line_len = (int)(sizeof(line_buf) - 3);

        std::lock_guard<std::mutex> lock(m_mutex);

        // 1. Store in circular ring buffer for crash diagnostics
        m_ring_buffer[m_ring_head] = std::string(line_buf, (size_t)line_len);
        m_ring_head = (m_ring_head + 1) % RING_CAPACITY;
        if (m_ring_count < RING_CAPACITY) {
            m_ring_count++;
        }

        // 2. Persist to file sink if within file threshold
        if (m_file && level <= m_file_min_level) {
            line_buf[line_len] = '\n';
            line_buf[line_len + 1] = '\0';
            size_t total_len = (size_t)line_len + 1;
            fwrite(line_buf, 1, total_len, m_file);
            fflush(m_file);
            m_bytes_written += total_len;
            if (m_bytes_written >= MAX_LOG_BYTES) {
                rotate_locked();
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
