package com.example.bluff

import android.app.Activity
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.animation.OvershootInterpolator
import kotlin.math.max

class SplashActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())

    private lateinit var nameView: RuhanTubarView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.statusBarColor = Color.rgb(9, 9, 14)
        window.navigationBarColor = Color.rgb(9, 9, 14)

        nameView = RuhanTubarView(this)

        setContentView(nameView)

        // Start the letter-by-letter animation.
        nameView.startAnimation()

        // Wait until the complete name has been shown clearly.
        handler.postDelayed({

            nameView.animate()
                .alpha(0f)
                .scaleX(1.05f)
                .scaleY(1.05f)
                .setDuration(500L)
                .setInterpolator(
                    OvershootInterpolator(1.2f)
                )
                .withEndAction {

                    startActivity(
                        Intent(
                            this,
                            MainActivity::class.java
                        )
                    )

                    overridePendingTransition(
                        android.R.anim.fade_in,
                        android.R.anim.fade_out
                    )

                    finish()
                }
                .start()

        }, 3900L)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}


/*
 * ============================================================
 * RUHANTUBAR CUSTOM LETTER-BY-LETTER SPLASH
 * ============================================================
 *
 * The entire word is drawn by one custom View.
 *
 * Each letter has its own:
 * - alpha
 * - scale
 * - animation delay
 *
 * This avoids manually positioning separate TextViews.
 */
class RuhanTubarView(
    context: android.content.Context
) : View(context) {

    private val text = "RuhanTubar"

    private val paint = Paint(
        Paint.ANTI_ALIAS_FLAG
    ).apply {
        color = Color.WHITE
        textSize = 64f
        typeface = Typeface.create(
            Typeface.DEFAULT,
            Typeface.NORMAL
        )
        textAlign = Paint.Align.LEFT
    }

    private val letterAlpha =
        FloatArray(text.length)

    private val letterScale =
        FloatArray(text.length)

    private val letterStartTime =
        LongArray(text.length)

    private var animationStartTime = 0L

    private var animationStarted = false

    private val interpolator =
        OvershootInterpolator(2f)

    init {
        alpha = 1f
        scaleX = 1f
        scaleY = 1f

        // Start with every letter hidden.
        for (i in text.indices) {
            letterAlpha[i] = 0f
            letterScale[i] = 0.45f
        }
    }

    fun startAnimation() {

        animationStarted = true

        animationStartTime =
            System.currentTimeMillis()

        /*
         * Each letter starts 120ms after
         * the previous one.
         */
        for (i in text.indices) {
            letterStartTime[i] =
                animationStartTime +
                    (i * 120L)
        }

        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (!animationStarted) {
            return
        }

        val now =
            System.currentTimeMillis()

        /*
         * Calculate total width of the word.
         */
        val widths =
            FloatArray(text.length)

        var totalWidth = 0f

        for (i in text.indices) {
            val width =
                paint.measureText(
                    text[i].toString()
                )

            widths[i] = width
            totalWidth += width
        }

        /*
         * Center the complete word.
         */
        var x =
            (width - totalWidth) / 2f

        /*
         * Baseline needed to vertically center
         * the text.
         */
        val fontMetrics =
            paint.fontMetrics

        val textHeight =
            fontMetrics.bottom -
                fontMetrics.top

        val baseY =
            height / 2f -
                (fontMetrics.ascent +
                    fontMetrics.descent) / 2f

        for (i in text.indices) {

            val elapsed =
                now -
                    letterStartTime[i]

            if (elapsed < 0) {
                /*
                 * This letter hasn't started yet.
                 */
                letterAlpha[i] = 0f
                letterScale[i] = 0.45f
            } else {

                val duration = 260L

                val progress =
                    (elapsed.toFloat() /
                        duration.toFloat())
                        .coerceIn(
                            0f,
                            1f
                        )

                val curved =
                    interpolator
                        .getInterpolation(
                            progress
                        )

                letterAlpha[i] =
                    progress

                letterScale[i] =
                    0.45f +
                        (1.12f - 0.45f) *
                            curved

                /*
                 * After the bounce, settle
                 * smoothly back to normal size.
                 */
                if (progress >= 1f) {

                    val settleElapsed =
                        elapsed - duration

                    val settleDuration =
                        140L

                    val settleProgress =
                        (
                            settleElapsed
                                .toFloat() /
                                settleDuration
                                    .toFloat()
                            ).coerceIn(
                                0f,
                                1f
                            )

                    val settle =
                        1f -
                            settleProgress

                    letterScale[i] =
                        1f +
                            0.12f *
                                settle
                }
            }

            /*
             * Draw the letter around its center
             * so scaling doesn't shift its position.
             */
            val letterWidth =
                widths[i]

            val centerX =
                x +
                    letterWidth / 2f

            canvas.save()

            canvas.translate(
                centerX,
                baseY
            )

            canvas.scale(
                letterScale[i],
                letterScale[i]
            )

            paint.alpha =
                (letterAlpha[i] * 255f)
                    .toInt()
                    .coerceIn(
                        0,
                        255
                    )

            canvas.drawText(
                text[i].toString(),
                -letterWidth / 2f,
                0f,
                paint
            )

            canvas.restore()

            x += letterWidth
        }

        paint.alpha = 255

        /*
         * Keep drawing while the animation is active.
         */
        val lastLetterStart =
            letterStartTime[
                text.length - 1
            ]

        if (
            now <
                lastLetterStart +
                    500L
        ) {
            postInvalidateOnAnimation()
        }
    }

    override fun onMeasure(
        widthMeasureSpec: Int,
        heightMeasureSpec: Int
    ) {

        val desiredWidth =
            max(
                1,
                (
                    paint.measureText(text) +
                        40f
                    ).toInt()
            )

        val fontMetrics =
            paint.fontMetrics

        val desiredHeight =
            max(
                1,
                (
                    fontMetrics.bottom -
                        fontMetrics.top +
                        40f
                    ).toInt()
            )

        val measuredWidth =
            resolveSize(
                desiredWidth,
                widthMeasureSpec
            )

        val measuredHeight =
            resolveSize(
                desiredHeight,
                heightMeasureSpec
            )

        setMeasuredDimension(
            measuredWidth,
            measuredHeight
        )
    }
}