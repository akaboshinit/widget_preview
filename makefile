start-viewer:
	pushd ./preview_viewer && flutter run -d chrome

start-background:
	dart run bin/find_previews.dart
