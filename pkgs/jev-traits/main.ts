#!/usr/bin/env bun
import { BunRuntime, BunServices } from '@effect/platform-bun'
import { Effect, Layer } from 'effect'
import { Command } from 'effect/cli'
import { FetchHttpClient } from 'effect/http'

import { jevTraits } from './JevTraits.ts'
import PackageJson from './package.json' with { type: 'json' }

jevTraits.pipe(
  Command.run({ version: PackageJson.version }),
  Effect.provide(Layer.mergeAll(BunServices.layer, FetchHttpClient.layer)),
  BunRuntime.runMain,
)
