import WebKit

/// Builds the JS payload injected at document-start, in every frame, for one
/// profile's fixed location. This is a direct port of the page-override.js
/// logic from the "Tab Location" extension: it monkey-patches
/// navigator.geolocation so that getCurrentPosition / watchPosition always
/// resolve with the profile's coordinates instead of hitting the real
/// Geolocation API.
enum GeolocationInjector {

    static func script(for profile: LocationProfile) -> WKUserScript {
        let source = makeSource(for: profile)
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    private static func detailJSON(for profile: LocationProfile) -> String {
        guard AppConfig.spoofEnabled else { return "{ enabled: false }" }
        return """
        { enabled: true, latitude: \(profile.latitude), longitude: \(profile.longitude), accuracy: \(profile.accuracy) }
        """
    }

    private static func makeSource(for profile: LocationProfile) -> String {
        let initialDetail = detailJSON(for: profile)
        return """
        (function() {
          if (window.__nativeLocationInstalled) return;
          Object.defineProperty(window, '__nativeLocationInstalled', { value: true, configurable: false, enumerable: false });

          const nativeGeolocation = navigator.geolocation;
          if (!nativeGeolocation) return;

          const nativeGet = nativeGeolocation.getCurrentPosition.bind(nativeGeolocation);
          const nativeWatch = nativeGeolocation.watchPosition.bind(nativeGeolocation);
          const nativeClear = nativeGeolocation.clearWatch.bind(nativeGeolocation);

          let ready = false;
          let current = null;
          let nextWatchId = 1000000;
          const pending = [];
          const watches = new Map();

          function position(loc) {
            const coords = {
              latitude: loc.latitude,
              longitude: loc.longitude,
              accuracy: loc.accuracy,
              altitude: null,
              altitudeAccuracy: null,
              heading: null,
              speed: null
            };
            return { coords: Object.freeze(coords), timestamp: Date.now() };
          }

          function asynchronously(callback, value) {
            setTimeout(() => {
              try { callback(value); } catch (error) { setTimeout(() => { throw error; }); }
            }, 0);
          }

          function startWatch(record) {
            if (record.cancelled) return;
            if (current) {
              record.mode = 'simulated';
              asynchronously(record.success, position(current));
            } else {
              record.mode = 'native';
              record.nativeId = nativeWatch(record.success, record.error, record.options);
            }
          }

          function getCurrentPosition(success, error, options) {
            if (typeof success !== 'function') return nativeGet(success, error, options);
            if (!ready) { pending.push({ type: 'get', success, error, options }); return; }
            if (current) asynchronously(success, position(current));
            else nativeGet(success, error, options);
          }

          function watchPosition(success, error, options) {
            if (typeof success !== 'function') return nativeWatch(success, error, options);
            const id = nextWatchId++;
            const record = { id, success, error, options, mode: 'pending', nativeId: null, cancelled: false };
            watches.set(id, record);
            if (ready) startWatch(record);
            else pending.push({ type: 'watch', id });
            return id;
          }

          function clearWatch(id) {
            const record = watches.get(id);
            if (!record) { nativeClear(id); return; }
            record.cancelled = true;
            if (record.mode === 'native' && record.nativeId != null) nativeClear(record.nativeId);
            watches.delete(id);
          }

          function applyUpdate(detail) {
            current = (detail && detail.enabled && Number.isFinite(detail.latitude) && Number.isFinite(detail.longitude))
              ? { latitude: detail.latitude, longitude: detail.longitude, accuracy: Number.isFinite(detail.accuracy) ? detail.accuracy : 50 }
              : null;
            ready = true;

            while (pending.length) {
              const op = pending.shift();
              if (op.type === 'get') getCurrentPosition(op.success, op.error, op.options);
              else { const record = watches.get(op.id); if (record) startWatch(record); }
            }

            for (const record of watches.values()) {
              if (record.cancelled) continue;
              if (current) {
                if (record.mode === 'native' && record.nativeId != null) { nativeClear(record.nativeId); record.nativeId = null; }
                record.mode = 'simulated';
                asynchronously(record.success, position(current));
              }
            }
          }

          try {
            Object.defineProperties(nativeGeolocation, {
              getCurrentPosition: { value: getCurrentPosition, configurable: true },
              watchPosition: { value: watchPosition, configurable: true },
              clearWatch: { value: clearWatch, configurable: true }
            });
          } catch (e) {
            navigator.geolocation.getCurrentPosition = getCurrentPosition;
            navigator.geolocation.watchPosition = watchPosition;
            navigator.geolocation.clearWatch = clearWatch;
          }

          applyUpdate(\(initialDetail));
        })();
        """
    }
}
