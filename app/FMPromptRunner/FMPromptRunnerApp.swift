//
//  FMPromptRunnerApp.swift
//  FMPromptRunner
//
//  Created by João Amaro Lagedo on 16/02/26.
//

import SwiftUI
import os

let logger = Logger(subsystem: "com.ficino.FMPromptRunner", category: "main")

@main
struct FMPromptRunnerApp: App {
    var body: some Scene {
        WindowGroup {
            Text("FMPromptRunner — CLI only")
        }
    }

    init() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard args.count >= 3 else {
            print("""
            Usage: FMPromptRunner <prompts.jsonl> <instructions.txt> <output.jsonl>

            Reads prompts JSONL, generates commentary via Apple Intelligence, writes output JSONL.

            Each input line must have: { "track", "artist", "album", "prompt" }
            Output adds: { ..., "response" }
            """)
            exit(1)
        }
        Task {
            await run(args)
            exit(0)
        }
    }
}
