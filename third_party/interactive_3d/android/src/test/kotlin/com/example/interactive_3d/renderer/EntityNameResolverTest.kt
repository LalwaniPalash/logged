package com.example.interactive_3d.renderer

import kotlin.test.Test
import kotlin.test.assertEquals

internal class EntityNameResolverTest {

    @Test
    fun buildRenderableEntityNameMap_attributes_all_primitives_to_their_named_node() {
        val namesByEntity = mapOf(
            100 to "forearm_extensors",
            200 to "adductors",
        )
        val parentsByTransformInstance = mapOf(
            101 to 100,
            102 to 100,
            100 to 1,
            201 to 200,
            202 to 200,
            203 to 200,
            200 to 1,
            1 to 0,
        )

        val resolved = EntityNameResolver.buildRenderableEntityNameMap(
            renderableEntities = intArrayOf(101, 102, 201, 202, 203),
            resolveDirectName = namesByEntity::get,
            hasTransformComponent = { entity -> entity in parentsByTransformInstance },
            getTransformInstance = { entity -> entity },
            getParentEntity = parentsByTransformInstance::getValue,
        )

        assertEquals("forearm_extensors", resolved[101])
        assertEquals("forearm_extensors", resolved[102])
        assertEquals("adductors", resolved[201])
        assertEquals("adductors", resolved[202])
        assertEquals("adductors", resolved[203])
    }
}
