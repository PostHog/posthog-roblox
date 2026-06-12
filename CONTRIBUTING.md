# Contributing to the PostHog Roblox SDK

Thanks for your interest in contributing! This page covers the contribution process. For the full
development setup (toolchain, tests, linting, running in Studio) see [DEVELOPMENT.md](DEVELOPMENT.md),
and for cutting a release see [RELEASING.md](RELEASING.md).

## Getting started

```sh
git clone https://github.com/PostHog/posthog-roblox.git
cd posthog-roblox
rokit install
```

`rokit install` downloads the pinned toolchain (Rojo, Wally, Selene, StyLua, Lune). See
[DEVELOPMENT.md](DEVELOPMENT.md) for what each tool does and how to run the SDK in Roblox Studio.

## Development workflow

Run these from the repo root after `rokit install`:

```sh
lune run tests/runTests.luau                  # Unit tests + 100% coverage gate
selene src tests                              # Lint
stylua --check src tests ExampleProject       # Check formatting (what CI runs)
```

CI runs the same checks, so run them before you push.

## Pull requests

1. **Create a branch** from `main` with a descriptive name.
2. **Write tests** for new functionality. Pure modules are held to a 100% coverage gate (see
   [DEVELOPMENT.md](DEVELOPMENT.md#tests-and-the-coverage-gate)).
3. **Run tests, lint and format** before submitting.
4. **Add a changeset** if your change should appear in the changelog: create a markdown file in
   `.sampo/changesets/` with the bump level (patch/minor/major) and a short summary:

   ```markdown
   ---
   posthog-roblox: patch
   ---

   A short, user-facing description of the change.
   ```

   See [RELEASING.md](RELEASING.md#adding-a-changeset) for details.
5. **Use a Conventional Commits PR title** (e.g. `feat: add feature flag polling`). CI validates this.

## Getting help

- Open an issue for bugs or feature requests.
- Check existing issues before creating new ones.
- Join the [PostHog community Slack](https://posthog.com/slack) for questions.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
