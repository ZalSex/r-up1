package com.pegasusx.revenge

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.ImageView
import androidx.core.app.NotificationCompat

class OverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private lateinit var overlayView: ImageView
    private val CHANNEL_ID = "overlay_channel"

    private var params: WindowManager.LayoutParams? = null

    private var dragStartX = 0f
    private var dragStartY = 0f
    private var viewStartX = 0
    private var viewStartY = 0
    private var isDragging = false
    private val DRAG_THRESHOLD_DP = 6f

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(1, buildNotification())
        showOverlay()
    }

    private fun showOverlay() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val density = resources.displayMetrics.density
        val sizePx = (56 * density).toInt()
        val dragThresholdPx = DRAG_THRESHOLD_DP * density

        val bitmap = loadCircularBitmap(sizePx)
        overlayView = ImageView(this).apply {
            setImageBitmap(bitmap)
            scaleType = ImageView.ScaleType.FIT_XY
        }

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

        params = WindowManager.LayoutParams(
            sizePx, sizePx,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 30
            y = 300
        }

        overlayView.setOnTouchListener { _, event ->
            val p = params ?: return@setOnTouchListener false
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    dragStartX = event.rawX
                    dragStartY = event.rawY
                    viewStartX = p.x
                    viewStartY = p.y
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - dragStartX
                    val dy = event.rawY - dragStartY
                    if (!isDragging && (Math.abs(dx) > dragThresholdPx || Math.abs(dy) > dragThresholdPx)) {
                        isDragging = true
                    }
                    if (isDragging) {
                        p.x = (viewStartX + dx).toInt()
                        p.y = (viewStartY + dy).toInt()
                        try { windowManager.updateViewLayout(overlayView, p) } catch (_: Exception) {}
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        try {
                            val launch = packageManager.getLaunchIntentForPackage(packageName)
                            launch?.apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                            }
                            launch?.let { startActivity(it) }
                        } catch (_: Exception) {}
                    }
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    isDragging = false
                    true
                }
                else -> false
            }
        }

        try {
            windowManager.addView(overlayView, params)
        } catch (_: Exception) {}
    }

    private fun loadCircularBitmap(sizePx: Int): Bitmap {
        val output = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        paint.color = Color.parseColor("#44000000")
        canvas.drawCircle(sizePx / 2f, sizePx / 2f + 2f, sizePx / 2f - 1f, paint)

        paint.color = Color.WHITE
        canvas.drawCircle(sizePx / 2f, sizePx / 2f, sizePx / 2f - 2f, paint)

        try {
            val stream = assets.open("icons/revenge.jpg")
            val bmp = BitmapFactory.decodeStream(stream)
            stream.close()

            val scaled = Bitmap.createScaledBitmap(bmp, sizePx, sizePx, true)
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
            canvas.drawBitmap(scaled, 0f, 0f, paint)
            paint.xfermode = null
        } catch (_: Exception) {
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
            paint.color = Color.parseColor("#1565C0")
            canvas.drawRect(0f, 0f, sizePx.toFloat(), sizePx.toFloat(), paint)
            paint.xfermode = null
            paint.color = Color.WHITE
            paint.textSize = sizePx * 0.42f
            paint.textAlign = Paint.Align.CENTER
            paint.isFakeBoldText = true
            try {
                val faTypeface = Typeface.createFromAsset(assets, "fonts/fa-solid-900.otf")
                paint.typeface = faTypeface
                canvas.drawText("\uF0AD", sizePx / 2f, sizePx / 2f + paint.textSize / 3f, paint)
            } catch (_: Exception) {
                canvas.drawText("R", sizePx / 2f, sizePx / 2f + paint.textSize / 3f, paint)
            }
        }

        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = (2.5f * resources.displayMetrics.density)
        }
        canvas.drawCircle(sizePx / 2f, sizePx / 2f, sizePx / 2f - 2f, border)

        return output
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Pegasus-X Revenge")
            .setContentText("Tap Tombol Floating Untuk Buka Aplikasi")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setSilent(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Revenge Overlay",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            if (::overlayView.isInitialized) windowManager.removeView(overlayView)
        } catch (_: Exception) {}
    }
}
