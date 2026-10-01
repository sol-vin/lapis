#pragma once

#include "common.hpp"
#include "gdextension_api.hpp"

/**
 * ==============================================================================
 * LibGodot - In-Editor XML Help Documentation Subsystem (editor_doc.hpp)
 * ==============================================================================
 *
 * Architecture & Integration:
 * ----------------------------
 * Godot's built-in offline Help system (accessible via F1 or Ctrl-clicking classes/methods)
 * reads class and member documentation from an internal XML database (`EditorHelp`).
 *
 * LibGodot's macro pipeline extracts doc comments (`# comments`) written in Crystal source
 * code above `node`, `property`, `signal`, and `def` declarations, generates Godot-compatible
 * `<class>` XML fragments at compile-time, and feeds them into `bridge_load_editor_help_xml`.
 *
 * Lifecycle:
 * - When game libraries initialize during SCENE level, XML strings are buffered in `g_editor_doc_xmls`.
 * - When Godot advances to GDEXTENSION_INITIALIZATION_EDITOR level, `bridge_flush_editor_help()`
 *   registers all buffered XML documents with `EditorHelp::load_xml_from_utf8_chars`.
 */

bool is_editor_active();

static std::vector<std::string> g_editor_doc_xmls;
static std::unordered_set<std::string> g_loaded_editor_doc_xmls;

/**
 * Resets the in-memory EditorHelp XML cache so that reloaded modules can refresh docs.
 */
inline void bridge_reset_editor_help_cache() {
    g_loaded_editor_doc_xmls.clear();
    g_editor_doc_xmls.clear();
}

/**
 * Loads an EditorHelp XML string for a registered Crystal class.
 *
 * If the engine is already at EDITOR level or the editor is active, the XML is passed
 * directly to Godot's `gd_editor_help_load_xml_from_utf8_chars`. Otherwise, it is stored
 * in `g_editor_doc_xmls` and flushed later via `bridge_flush_editor_help()`.
 *
 * @param xml Null-terminated UTF-8 XML document string matching Godot's EditorHelp schema.
 *
 * Segments:
 * - Segment 1: Parameter validation and Deduplication check.
 * - Segment 2: Immediate engine dispatch if editor interface is running.
 * - Segment 3: Storage in pending XML vector.
 */
inline void bridge_load_editor_help_xml(const char *xml) {
    // --- Segment 1: Validation & Deduplication ---
    if (!xml) return;
    std::string s(xml);

    if (g_loaded_editor_doc_xmls.find(s) != g_loaded_editor_doc_xmls.end()) {
        return;
    }
    g_loaded_editor_doc_xmls.insert(s);

    // --- Segment 2: Immediate Engine Dispatch if Editor is active ---
    if (gd_editor_help_load_xml_from_utf8_chars && g_current_init_level >= GDEXTENSION_INITIALIZATION_EDITOR) {
        gd_editor_help_load_xml_from_utf8_chars(xml);
        return;
    }

    // --- Segment 3: Pending Vector Storage ---
    g_editor_doc_xmls.push_back(s);
}

/**
 * Flushes all pending EditorHelp XML documents into Godot's offline help database.
 * Called during module lifecycle transition to GDEXTENSION_INITIALIZATION_EDITOR.
 *
 * Segments:
 * - Segment 1: Interface pointer check and empty queue fast-return.
 * - Segment 2: Iterating documents and calling gd_editor_help_load_xml_from_utf8_chars.
 * - Segment 3: Status logging to console.
 */
inline void bridge_flush_editor_help() {
    // --- Segment 1: Interface & Queue Check ---
    if (!gd_editor_help_load_xml_from_utf8_chars) return;
    if (g_editor_doc_xmls.empty()) return;

    // --- Segment 2: Document Iteration & Registration ---
    for (const auto &xml : g_editor_doc_xmls) {
        gd_editor_help_load_xml_from_utf8_chars(xml.c_str());
    }

    // --- Segment 3: Status Logging ---
    char log_buf[128];
    snprintf(log_buf, sizeof(log_buf), "[CrystalBridge] Flushed %zu EditorHelp XML documentation document(s) into Godot", g_editor_doc_xmls.size());
    godot_log_print(log_buf);
}
