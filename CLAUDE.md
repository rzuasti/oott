# Project OOTT

OOTT is an easy to setup network monitoring and alert system aimed at notifying when new or unknown devices join a local area network.

It has two major components:
- A backend service that runs the monitoring and other processes and provides a REST API. This is built with [Rust](https://rust-lang.org/).
- A front-end that enables the user to configure the system and access the data it stores. This is built with [Flutter](https://flutter.dev/) - a front-end framework based on the [Dart](https://dart.dev/) language.


## Code style

For Rust code:
- Use the standard [Rust style guide](https://doc.rust-lang.org/style-guide/)
- Use `rustfmt` to format the code

For Flutter/Dart code:
- Use the standard [Dart style guide](https://dart.dev/effective-dart/style)
- Use `dart format --output show` to format the code

## Project commands

- `` - Run the backend
- `` - Run the front-end for the web
- `` - Run the backend tests

## Architecture

### General
- All backend source code is under the `backend/` folder
- All front-end source code is under the `frontend/` folder
- All interactions between the front-end and the backend are via the backend REST API

### Backend
- System state and events are stored in a SQLite database (`oott.db` by default) which is accessed and managed exclusively by the backend via a data access layer (`db.rs` and files under the `backend/src/db/` folder)
- Database structure is handled through incremental migrations (stored under the `backend/database_migrations` folder). Each set of structural changes should be a new database migration file.
- The backend's entry point is `src/main.rs` which starts two threads using the [Tokyo](https://tokio.rs/) framework: one for the network scanning process and another one for the web server that exposes the API and hosts the Flutter app (front-end) assets when deployed in a live environment (ie not development)

### Front-end
- The front-end's entry point is `lib/main.dart`
- It uses the [Material 3](https://m3.material.io/develop/flutter) framework for Flutter
- The application needs to be responsive and adapt to a web experience in the desktop, tablets and phones
- The application is also available in iOS and Android as a native experience (via de App Store and Play store) 
 
## Important notes
