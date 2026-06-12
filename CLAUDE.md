# Project OOTT

OOTT is an easy-to-setup network monitoring and alert system that notifies when new or unknown devices join a local area network. Two components, communicating exclusively via the backend's REST API:

- **Backend** (`backend/`): [Rust](https://rust-lang.org/), edition 2024. Runs the monitoring processes and exposes the REST API.
- **Front-end** (`frontend/`): [Flutter](https://flutter.dev/) / [Dart](https://dart.dev/). Configures the system and accesses stored data.

## Architecture

### Backend
- Entry point `src/main.rs` starts two [Tokio](https://tokio.rs/) threads: one for network scanning, one for the web server (serves the API and, in non-dev deployments, hosts the Flutter assets).
- State and events live in a SQLite database (`oott.db` by default), accessed exclusively through the data access layer (`db.rs` and `backend/src/db/`).
- Schema changes go through incremental migrations in `backend/database_migrations/`. Each set of structural changes is a new migration file.

### Front-end
- Entry point `lib/main.dart`, built on [Material 3](https://m3.material.io/develop/flutter).
- Must be responsive across desktop web, tablet, and phone, and ships as a native iOS/Android app (App Store / Play Store).
- All backend API access goes through `utils/oott_api.dart`.

## Commands

| Command | Purpose |
| --- | --- |
| `cd backend && ./build.sh` | Build the backend |
| `cd backend && ./run.sh` | Run the backend |
| `cd backend && ./run_tests.sh` | Run backend tests |
| `cd backend && ./lint.sh` | Run clippy (Rust linter) |
| `cd frontend && ./run_web.sh` | Run the front-end for web |
| `cd frontend && ./run_android_emulator.sh` | Boot the Android emulator (if needed) and run the front-end |
| `cd frontend && ./run_tests.sh` | Run front-end tests |
| `dart analyze` | Run the Dart linter |
| `cd backend/data && ./update_mac_vendors --llm` | Update MAC vendor list and recalculate the vendor → device-type mapping |

## Code style

- **Rust**: standard [Rust style guide](https://doc.rust-lang.org/style-guide/). Format with `rustfmt`; always pass `--edition 2024` (e.g. `rustfmt --edition 2024 <file>`) to avoid spurious import-ordering changes. Avoid import aliases (`use ... as ...`) unless necessary.
- **Dart**: standard [Dart style guide](https://dart.dev/effective-dart/style). Format with `dart format --output show`.
- All code must be as simple, human-readable, and modular as possible.

## Testing & linting

- Write/update tests for every new or modified component: unit tests (backend); unit, API, and widget tests (frontend).
- After any change, run all tests and do not continue until they pass.
- Run the matching linter after adding a significant chunk of Rust or Dart.

## Front-end conventions

- Use the `UISnackbars` component for messages that need no user action.
- Use colors from the selected theme only — never hard-code them. If a needed color isn't covered semantically by the theme, propose an addition to the project's theme extension.
- Prefer built-in Flutter/Material components. Build a custom one only when it's genuinely a better fit, and in that case present the custom-vs-built-in trade-offs to the human and get confirmation first.
- Keep new screens/widgets/dialogs consistent with existing similar widgets and with Material 3 guidance (button emphasis hierarchy, action placement, theming).

## Workflow

- Commit directly to `main` by default; don't create branches (single-developer project).
- Always commit `TODO.md` when it changes, without ticking items — it's fully human-managed.
- Keep formatter changes: never revert a file just because the formatter reformatted it (even files you didn't otherwise touch), and add such changes to the current commit. Revert only if the reformatting actually introduces a bug.

## Must / must not

- When adding a new API endpoint, always wire it into the OpenAPI generation.
- NEVER add or commit `.env` files or any files containing secrets (passwords, API keys, etc.).
