import glob, os
g = glob.glob('android/app/build.gradle*')
assert len(g) == 1, g
f = g[0]
kts = f.endswith('.kts')
s = open(f).read()
a = 'compileOptions {\n'
assert s.count(a) == 1
s = s.replace(a, a + ('        isCoreLibraryDesugaringEnabled = true\n' if kts else '        coreLibraryDesugaringEnabled true\n'))
a = 'release {\n'
assert s.count(a) == 1
s = s.replace(a, a + ('            isMinifyEnabled = false\n            isShrinkResources = false\n' if kts else '            minifyEnabled false\n            shrinkResources false\n'))
if kts:
    s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.4")\n    implementation("com.github.teamnewpipe:NewPipeExtractor:v0.26.4")\n}\n'
else:
    s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs_nio:2.1.4'\n    implementation 'com.github.teamnewpipe:NewPipeExtractor:v0.26.4'\n}\n"
open(f, 'w').write(s)

d = os.path.expanduser('~/.gradle/init.d')
os.makedirs(d, exist_ok=True)
open(d + '/repos.gradle', 'w').write("allprojects {\n    repositories {\n        maven { url 'https://jitpack.io' }\n    }\n}\n")

k = glob.glob('android/app/src/main/kotlin/**/MainActivity.kt', recursive=True)
assert k, 'no MainActivity.kt'
old = open(k[0]).read()
pkg = [l for l in old.splitlines() if l.startswith('package ')][0].split()[1]
KT = r'''package @@PKG@@

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import org.schabi.newpipe.extractor.stream.StreamInfo
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

const val UA = "Mozilla/5.0 (Windows NT 10.0; rv:128.0) Gecko/20100101 Firefox/128.0"

class Dl : Downloader() {
    override fun execute(request: Request): Response {
        val c = URL(request.url()).openConnection() as HttpURLConnection
        c.requestMethod = request.httpMethod()
        c.connectTimeout = 30000
        c.readTimeout = 30000
        c.setRequestProperty("User-Agent", UA)
        for ((k, v) in request.headers()) {
            c.setRequestProperty(k, v.joinToString(", "))
        }
        val data = request.dataToSend()
        if (data != null) {
            c.doOutput = true
            c.outputStream.use { it.write(data) }
        }
        val code = c.responseCode
        if (code == 429) throw ReCaptchaException("429", request.url())
        val s = if (code >= 400) c.errorStream else c.inputStream
        val body = s?.bufferedReader()?.use { it.readText() } ?: ""
        val h = HashMap<String, List<String>>()
        for ((k, v) in c.headerFields) {
            if (k != null) h[k] = v
        }
        return Response(code, c.responseMessage ?: "", h, body, c.url.toString())
    }
}

class MainActivity : AudioServiceActivity() {
    private var ready = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bitchord/yt")
            .setMethodCallHandler { call, result ->
                if (call.method == "audio") {
                    val id = call.arguments as String
                    Thread {
                        try {
                            val p = fetch(id)
                            runOnUiThread { result.success(p) }
                        } catch (e: Throwable) {
                            runOnUiThread { result.error("yt", e.toString(), null) }
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun fetch(id: String): String {
        if (!ready) {
            NewPipe.init(Dl())
            ready = true
        }
        val info = StreamInfo.getInfo("https://www.youtube.com/watch?v=" + id)
        val a = info.audioStreams.filter { it.isUrl }.maxByOrNull { it.averageBitrate }
            ?: throw Exception("sin audio")
        val url = a.content
        val ext = a.format?.suffix ?: "m4a"
        val file = File(cacheDir, "np_" + id + "." + ext)
        if (file.exists() && file.length() > 0) return file.path
        val tmp = File(cacheDir, "np_" + id + ".part")
        var got = 0L
        var total = -1L
        tmp.outputStream().use { out ->
            while (total < 0 || got < total) {
                val c = URL(url).openConnection() as HttpURLConnection
                c.setRequestProperty("Range", "bytes=" + got + "-" + (got + 1048575))
                c.setRequestProperty("User-Agent", UA)
                c.connectTimeout = 20000
                c.readTimeout = 30000
                val code = c.responseCode
                if (code != 200 && code != 206) throw Exception("HTTP " + code)
                val cr = c.getHeaderField("Content-Range")
                total = if (cr != null) cr.substringAfter("/").toLong() else c.contentLengthLong
                val n = c.inputStream.use { it.copyTo(out) }
                if (n <= 0L) throw Exception("sin datos")
                got += n
                if (code == 200) break
            }
        }
        tmp.renameTo(file)
        return file.path
    }
}
'''
open(k[0], 'w').write(KT.replace('@@PKG@@', pkg))
print('np ok', f)
