pragma Singleton

import QtQuick
import Quickshell

// Catalogue of providers + models HexinAgent can talk to.
//
// Every provider is "bring your own key": the key is entered in the agent's own
// settings view and stored locally in the state directory (never in the shell
// settings file). `kind` tells the daemon which wire format to speak.
//
// Anything not listed here still works through the "Custom" provider, where the
// base URL and model id are typed by hand.
Singleton {
    id: root

    readonly property var providers: [
        {
            id: "openai",
            name: "OpenAI",
            glyph: "",
            kind: "openai",
            baseUrl: "https://api.openai.com/v1",
            keyHint: "sk-...",
            models: ["gpt-5", "gpt-5-mini", "gpt-5-nano", "gpt-4.1", "gpt-4.1-mini", "gpt-4o", "gpt-4o-mini", "o3", "o4-mini"]
        },
        {
            id: "anthropic",
            name: "Anthropic",
            glyph: "",
            kind: "anthropic",
            baseUrl: "https://api.anthropic.com/v1",
            keyHint: "sk-ant-...",
            models: ["claude-opus-4-1", "claude-sonnet-4-5", "claude-haiku-4-5", "claude-3-7-sonnet-latest", "claude-3-5-haiku-latest"]
        },
        {
            id: "google",
            name: "Google Gemini",
            glyph: "",
            kind: "openai",
            baseUrl: "https://generativelanguage.googleapis.com/v1beta/openai",
            keyHint: "AIza...",
            models: ["gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.0-flash"]
        },
        {
            id: "deepseek",
            name: "DeepSeek",
            glyph: "",
            kind: "openai",
            baseUrl: "https://api.deepseek.com/v1",
            keyHint: "sk-...",
            models: ["deepseek-chat", "deepseek-reasoner"]
        },
        {
            id: "xai",
            name: "xAI",
            glyph: "",
            kind: "openai",
            baseUrl: "https://api.x.ai/v1",
            keyHint: "xai-...",
            models: ["grok-4", "grok-3", "grok-3-mini"]
        },
        {
            id: "mistral",
            name: "Mistral",
            glyph: "",
            kind: "openai",
            baseUrl: "https://api.mistral.ai/v1",
            keyHint: "...",
            models: ["mistral-large-latest", "mistral-medium-latest", "mistral-small-latest", "codestral-latest"]
        },
        {
            id: "groq",
            name: "Groq",
            glyph: "",
            kind: "openai",
            baseUrl: "https://api.groq.com/openai/v1",
            keyHint: "gsk_...",
            models: ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "qwen/qwen3-32b", "moonshotai/kimi-k2-instruct", "openai/gpt-oss-120b"]
        },
        {
            id: "together",
            name: "Together",
            glyph: "",
            kind: "openai",
            baseUrl: "https://api.together.xyz/v1",
            keyHint: "...",
            models: ["meta-llama/Llama-3.3-70B-Instruct-Turbo", "Qwen/Qwen2.5-72B-Instruct-Turbo", "deepseek-ai/DeepSeek-V3"]
        },
        {
            id: "openrouter",
            name: "OpenRouter",
            glyph: "",
            kind: "openai",
            baseUrl: "https://openrouter.ai/api/v1",
            keyHint: "sk-or-...",
            models: ["openrouter/auto", "anthropic/claude-sonnet-4.5", "openai/gpt-5", "google/gemini-2.5-pro", "deepseek/deepseek-chat", "qwen/qwen3-235b-a22b"]
        },
        {
            id: "cerebras",
            name: "Cerebras",
            glyph: "",
            kind: "openai",
            baseUrl: "https://api.cerebras.ai/v1",
            keyHint: "csk-...",
            models: ["llama-3.3-70b", "llama3.1-8b"]
        },
        {
            id: "ollama",
            name: "Ollama (local)",
            glyph: "",
            kind: "openai",
            baseUrl: "http://localhost:11434/v1",
            keyHint: "not needed",
            local: true,
            models: ["qwen3", "llama3.2", "deepseek-r1", "mistral", "gemma3", "phi4"]
        },
        {
            id: "lmstudio",
            name: "LM Studio (local)",
            glyph: "",
            kind: "openai",
            baseUrl: "http://localhost:1234/v1",
            keyHint: "not needed",
            local: true,
            models: ["local-model"]
        },
        {
            id: "custom",
            name: "Custom endpoint",
            glyph: "",
            kind: "openai",
            baseUrl: "",
            keyHint: "your key",
            models: []
        }
    ]

    readonly property var names: providers.map(p => p.name)

    function byId(id) {
        for (let i = 0; i < providers.length; i++) {
            if (providers[i].id === id)
                return providers[i];
        }
        return providers[0];
    }

    function modelsFor(id) {
        const p = byId(id);
        return p && p.models ? p.models : [];
    }

    function providerOfModel(model) {
        for (let i = 0; i < providers.length; i++) {
            if ((providers[i].models || []).indexOf(model) >= 0)
                return providers[i];
        }
        return null;
    }

    // Flat list of every known model, for the "all models" picker.
    function allModels() {
        const out = [];
        for (let i = 0; i < providers.length; i++) {
            const p = providers[i];
            for (let j = 0; j < (p.models || []).length; j++) {
                out.push({
                    provider: p.id,
                    providerName: p.name,
                    model: p.models[j]
                });
            }
        }
        return out;
    }

    function needsKey(id) {
        const p = byId(id);
        return !(p && p.local);
    }
}
