{{flutter_js}}
{{flutter_build_config}}

// Version the entrypoint as well as the loader so previously cached JavaScript
// cannot hide the columns and users update after deployment.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath += '?v=20261007-iconos';
  }
}
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  }
});
