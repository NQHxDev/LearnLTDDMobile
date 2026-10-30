package com.nguyen_quang_hung.ltddexam

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterFragmentActivity() {
    private val locationChannelName = "com.nguyen_quang_hung.ltddexam/location"
    private val locationStreamChannelName = "com.nguyen_quang_hung.ltddexam/location_stream"

    private val bgExecutor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var streamListener: LocationListener? = null
    private var bestStreamLocation: Location? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, locationChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isLocationServiceEnabled" -> {
                        result.success(isLocationEnabled())
                    }
                    "getCurrentLocation" -> {
                        val waitFresh = call.argument<Boolean>("waitFresh") ?: true
                        fetchHighAccuracyLocation(waitFresh, result)
                    }
                    "reverseGeocode" -> {
                        val lat = call.argument<Double>("latitude")
                        val lng = call.argument<Double>("longitude")
                        if (lat == null || lng == null) {
                            result.error("INVALID_ARGS", "Thiếu tọa độ latitude/longitude", null)
                        } else {
                            bgExecutor.execute {
                                val geoMap = resolveNativeAddress(lat, lng)
                                mainHandler.post {
                                    result.success(geoMap)
                                }
                            }
                        }
                    }
                    "openLocationSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "openExternalMap" -> {
                        val lat = call.argument<Double>("latitude") ?: 0.0
                        val lng = call.argument<Double>("longitude") ?: 0.0
                        val label = call.argument<String>("label") ?: "Vị trí chia sẻ"
                        val opened = openExternalMapApp(lat, lng, label)
                        result.success(opened)
                    }
                    "shareText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val subject = call.argument<String>("subject") ?: "Chia sẻ vị trí GPS"
                        val shared = shareTextNative(text, subject)
                        result.success(shared)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, locationStreamChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    startRealtimeLocationStream(events)
                }

                override fun onCancel(arguments: Any?) {
                    stopRealtimeLocationStream()
                }
            })
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun isLocationEnabled(): Boolean {
        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lm.isLocationEnabled
        } else {
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
    }

    @SuppressLint("MissingPermission")
    private fun fetchHighAccuracyLocation(waitFresh: Boolean, result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            result.error("PERMISSION_DENIED", "Chưa cấp quyền truy cập vị trí GPS", null)
            return
        }

        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (lm == null) {
            result.error("UNAVAILABLE", "Không thể truy cập dịch vụ định vị trên thiết bị", null)
            return
        }

        if (!isLocationEnabled()) {
            result.error("LOCATION_DISABLED", "Dịch vụ định vị GPS trên điện thoại đang tắt", null)
            return
        }

        val completed = AtomicBoolean(false)
        var bestCandidate: Location? = getBestLastKnownLocation(lm)

        val now = System.currentTimeMillis()
        // Nếu đã có vị trí cực mới (< 10 giây) và độ chính xác rất cao (<= 12m) và không bắt buộc chờ lâu
        if (!waitFresh && bestCandidate != null &&
            (now - bestCandidate!!.time) < 10_000L &&
            bestCandidate!!.accuracy in 0.1f..12.0f
        ) {
            deliverLocationResult(bestCandidate!!, result)
            return
        }

        val providers = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && lm.allProviders.contains(LocationManager.FUSED_PROVIDER)) {
            if (lm.isProviderEnabled(LocationManager.FUSED_PROVIDER)) {
                providers.add(LocationManager.FUSED_PROVIDER)
            }
        }
        if (lm.allProviders.contains(LocationManager.GPS_PROVIDER) && lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            providers.add(LocationManager.GPS_PROVIDER)
        }
        if (lm.allProviders.contains(LocationManager.NETWORK_PROVIDER) && lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            providers.add(LocationManager.NETWORK_PROVIDER)
        }
        if (lm.allProviders.contains(LocationManager.PASSIVE_PROVIDER)) {
            providers.add(LocationManager.PASSIVE_PROVIDER)
        }

        val tempListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (isBetterLocation(location, bestCandidate)) {
                    bestCandidate = location
                }
                // Nếu đạt độ chính xác tốt (<= 35m) từ GPS, Network hoặc Fused, trả kết quả ngay
                if (location.accuracy in 0.1f..35.0f && completed.compareAndSet(false, true)) {
                    try {
                        lm.removeUpdates(this)
                    } catch (_: Exception) {}
                    deliverLocationResult(bestCandidate ?: location, result)
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }

        try {
            for (provider in providers) {
                lm.requestLocationUpdates(provider, 200L, 0.0f, tempListener, Looper.getMainLooper())
            }
        } catch (_: Exception) {}

        // Chờ tối đa 4000ms để bắt tín hiệu vệ tinh GPS / mạng rồi trả về ứng viên tốt nhất
        mainHandler.postDelayed({
            if (completed.compareAndSet(false, true)) {
                try {
                    lm.removeUpdates(tempListener)
                } catch (_: Exception) {}

                val finalLoc = bestCandidate ?: getBestLastKnownLocation(lm)
                if (finalLoc != null) {
                    deliverLocationResult(finalLoc, result)
                } else {
                    result.error(
                        "TIMEOUT_NO_FIX",
                        "Chưa thu được tín hiệu vệ tinh GPS. Vui lòng đứng ở nơi thoáng hoặc kiểm tra cài đặt vị trí.",
                        null
                    )
                }
            }
        }, 4000L)
    }

    @SuppressLint("MissingPermission")
    private fun getBestLastKnownLocation(lm: LocationManager): Location? {
        val candidateProviders = mutableListOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            candidateProviders.add(0, LocationManager.FUSED_PROVIDER)
        }

        var best: Location? = null
        for (p in candidateProviders) {
            try {
                if (lm.allProviders.contains(p)) {
                    val loc = lm.getLastKnownLocation(p)
                    if (loc != null && isBetterLocation(loc, best)) {
                        best = loc
                    }
                }
            } catch (_: Exception) {}
        }
        return best
    }

    private fun isBetterLocation(location: Location, currentBestLocation: Location?): Boolean {
        if (currentBestLocation == null) return true

        val timeDelta = location.time - currentBestLocation.time
        val isSignificantlyNewer = timeDelta > 45_000L
        val isSignificantlyOlder = timeDelta < -45_000L
        val isNewer = timeDelta > 0L

        if (isSignificantlyNewer) return true
        if (isSignificantlyOlder) return false

        val accuracyDelta = (location.accuracy - currentBestLocation.accuracy).toInt()
        val isLessAccurate = accuracyDelta > 0
        val isMoreAccurate = accuracyDelta < 0
        val isSignificantlyLessAccurate = accuracyDelta > 50

        val isFromSameProvider = location.provider == currentBestLocation.provider

        if (isMoreAccurate) return true
        if (isNewer && !isLessAccurate) return true
        if (isNewer && !isSignificantlyLessAccurate && isFromSameProvider) return true
        return false
    }

    private fun deliverLocationResult(location: Location, result: MethodChannel.Result) {
        bgExecutor.execute {
            val payload = locationToMap(location, includeGeocoder = true)
            mainHandler.post {
                result.success(payload)
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startRealtimeLocationStream(events: EventChannel.EventSink?) {
        stopRealtimeLocationStream()
        if (events == null || !hasLocationPermission()) return

        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return
        bestStreamLocation = getBestLastKnownLocation(lm)

        bestStreamLocation?.let { initial ->
            bgExecutor.execute {
                val map = locationToMap(initial, includeGeocoder = true)
                mainHandler.post {
                    try {
                        events.success(map)
                    } catch (_: Exception) {}
                }
            }
        }

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (isBetterLocation(location, bestStreamLocation)) {
                    bestStreamLocation = location
                }
                val chosen = bestStreamLocation ?: location
                bgExecutor.execute {
                    val map = locationToMap(chosen, includeGeocoder = false)
                    mainHandler.post {
                        try {
                            events.success(map)
                        } catch (_: Exception) {}
                    }
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }

        streamListener = listener

        val providers = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && lm.allProviders.contains(LocationManager.FUSED_PROVIDER)) {
            if (lm.isProviderEnabled(LocationManager.FUSED_PROVIDER)) {
                providers.add(LocationManager.FUSED_PROVIDER)
            }
        }
        if (lm.allProviders.contains(LocationManager.GPS_PROVIDER) && lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            providers.add(LocationManager.GPS_PROVIDER)
        }
        if (lm.allProviders.contains(LocationManager.NETWORK_PROVIDER) && lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            providers.add(LocationManager.NETWORK_PROVIDER)
        }

        try {
            for (p in providers) {
                lm.requestLocationUpdates(p, 1500L, 1.0f, listener, Looper.getMainLooper())
            }
        } catch (_: Exception) {}
    }

    private fun stopRealtimeLocationStream() {
        val listener = streamListener ?: return
        streamListener = null
        try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            lm?.removeUpdates(listener)
        } catch (_: Exception) {}
    }

    private fun locationToMap(location: Location, includeGeocoder: Boolean): Map<String, Any?> {
        val providerRaw = (location.provider ?: "gps").lowercase(Locale.ROOT)
        val providerLabel = when {
            providerRaw.contains("gps") -> "GPS_SATELLITE"
            providerRaw.contains("fused") -> "FUSED_HIGH_ACCURACY"
            providerRaw.contains("network") -> "NETWORK_WIFI_CELL"
            else -> "PASSIVE_SENSOR"
        }

        val satellites = location.extras?.getInt("satellites", 0) ?: 0
        val isMock = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            location.isMock
        } else {
            @Suppress("DEPRECATION")
            location.isFromMockProvider
        }

        val map = mutableMapOf<String, Any?>(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to if (location.hasAccuracy()) location.accuracy.toDouble() else 5.0,
            "altitude" to if (location.hasAltitude()) location.altitude else 0.0,
            "speed" to if (location.hasSpeed()) location.speed.toDouble() else 0.0,
            "bearing" to if (location.hasBearing()) location.bearing.toDouble() else 0.0,
            "provider" to providerLabel,
            "satellites" to satellites,
            "isMock" to isMock,
            "timestamp" to location.time
        )

        if (includeGeocoder) {
            val geo = resolveNativeAddress(location.latitude, location.longitude)
            map.putAll(geo)
        }

        return map
    }

    @Suppress("DEPRECATION")
    private fun resolveNativeAddress(lat: Double, lng: Double): Map<String, String?> {
        val out = mutableMapOf<String, String?>(
            "nativeAddress" to null,
            "ward" to null,
            "district" to null,
            "city" to null
        )
        if (!Geocoder.isPresent()) return out

        try {
            val geocoder = Geocoder(this, Locale("vi", "VN"))
            val addresses = geocoder.getFromLocation(lat, lng, 1)
            if (!addresses.isNullOrEmpty()) {
                val addr = addresses[0]
                val fullLine = addr.getAddressLine(0)
                val ward = addr.subLocality ?: addr.thoroughfare
                val district = addr.subAdminArea ?: addr.locality
                val city = addr.adminArea ?: addr.countryName

                out["nativeAddress"] = fullLine
                out["ward"] = ward
                out["district"] = district
                out["city"] = city
            }
        } catch (_: Exception) {}

        return out
    }

    private fun openExternalMapApp(lat: Double, lng: Double, label: String): Boolean {
        val encodedLabel = Uri.encode(label)
        try {
            // Thử mở trực tiếp ứng dụng Bản đồ (Google Maps / mặc định) bằng geo: URI
            val geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng($encodedLabel)")
            val mapIntent = Intent(Intent.ACTION_VIEW, geoUri)
            mapIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(mapIntent)
            return true
        } catch (_: Exception) {
            try {
                // Fallback sang trình duyệt Google Maps chuẩn
                val webUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng")
                val webIntent = Intent(Intent.ACTION_VIEW, webUri)
                webIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(webIntent)
                return true
            } catch (_: Exception) {
                return false
            }
        }
    }

    private fun shareTextNative(text: String, subject: String): Boolean {
        return try {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_SUBJECT, subject)
                putExtra(Intent.EXTRA_TEXT, text)
            }
            val chooser = Intent.createChooser(sendIntent, subject)
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooser)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onDestroy() {
        stopRealtimeLocationStream()
        super.onDestroy()
    }
}
