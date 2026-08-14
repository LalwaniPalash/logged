package com.example.interactive_3d.renderer

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

internal class CameraControllerTest {

    @Test
    fun resetOrbit_restores_default_angles_and_zoom_without_changing_fit_radius() {
        val clock = FakeClock()
        val controller = CameraController(
            currentTimeMillis = clock::now,
            idleScheduler = FakeIdleScheduler(),
        )

        controller.fitToBoundingBox(
            center = floatArrayOf(1f, 2f, 3f),
            halfExtent = floatArrayOf(0.5f, 0.8f, 1.2f),
        )
        val fittedRadius = controller.orbitRadius

        clock.advance(10L)
        assertTrue(controller.onPan(deltaX = 10f, deltaY = -5f))
        clock.advance(10L)
        assertTrue(controller.onScale(1.8f))

        assertTrue(controller.orbitAngleX != 0.0f)
        assertTrue(controller.orbitAngleY != 0.0f)
        assertTrue(controller.zoomLevel > 1.0f)

        controller.resetOrbit()

        assertEquals(0.0f, controller.orbitAngleX)
        assertEquals(0.0f, controller.orbitAngleY)
        assertEquals(1.0f, controller.zoomLevel)
        assertEquals(fittedRadius, controller.orbitRadius)
    }

    @Test
    fun resetOrbit_restores_the_zoom_the_model_was_loaded_at_not_a_hardcoded_value() {
        val clock = FakeClock()
        val controller = CameraController(
            currentTimeMillis = clock::now,
            idleScheduler = FakeIdleScheduler(),
        )

        controller.fitToBoundingBox(
            center = floatArrayOf(0f, 0f, 0f),
            halfExtent = floatArrayOf(1f, 1f, 1f),
        )
        // Mirrors the app's initial-load call: Dart sends defaultZoom=3.0
        // right after the model loads.
        controller.setZoom(3.0f)

        clock.advance(10L)
        controller.onScale(0.5f) // user pinches out mid-session
        assertTrue(controller.zoomLevel < 3.0f)

        controller.resetOrbit()

        assertEquals(3.0f, controller.zoomLevel)
    }
}

private class FakeIdleScheduler : IdleScheduler {
    override fun removeCallbacks(runnable: Runnable) = Unit

    override fun postDelayed(runnable: Runnable, delayMs: Long) = Unit
}

private class FakeClock(
    private var currentTimeMillis: Long = 0L,
) {
    fun now(): Long = currentTimeMillis

    fun advance(deltaMs: Long) {
        currentTimeMillis += deltaMs
    }
}
