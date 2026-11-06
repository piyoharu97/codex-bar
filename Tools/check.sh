#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p .build/ModuleCache
swiftc -module-cache-path .build/ModuleCache Shared/Quota.swift App/CodexClient.swift Tests/QuotaTests.swift -o .build/tests
.build/tests "$PWD/Tests/mock-codex.py"
swiftc -module-cache-path .build/ModuleCache Shared/ReleaseVersion.swift Tests/ReleaseVersionTests.swift -o .build/version-tests
.build/version-tests
swiftc -module-cache-path .build/ModuleCache Shared/ReleaseVersion.swift Shared/PublicReleaseFeed.swift Tests/PublicReleaseFeedTests.swift -o .build/feed-tests
.build/feed-tests
swiftc -module-cache-path .build/ModuleCache -typecheck Shared/*.swift App/*.swift Desktop/*.swift
