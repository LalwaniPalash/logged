package com.example.interactive_3d.renderer

/**
 * Resolves picked / selected renderable entities back to the nearest named
 * glTF node by walking up the Filament transform hierarchy.
 */
internal object EntityNameResolver {

    fun buildRenderableEntityNameMap(
        renderableEntities: IntArray,
        resolveDirectName: (Int) -> String?,
        hasTransformComponent: (Int) -> Boolean,
        getTransformInstance: (Int) -> Int,
        getParentEntity: (Int) -> Int,
    ): Map<Int, String> {
        if (renderableEntities.isEmpty()) return emptyMap()

        val resolved = mutableMapOf<Int, String>()
        for (entity in renderableEntities) {
            val name = resolveNearestNamedAncestor(
                entity = entity,
                resolveDirectName = resolveDirectName,
                hasTransformComponent = hasTransformComponent,
                getTransformInstance = getTransformInstance,
                getParentEntity = getParentEntity,
            )
            if (name != null) {
                resolved[entity] = name
            }
        }
        return resolved
    }

    private fun resolveNearestNamedAncestor(
        entity: Int,
        resolveDirectName: (Int) -> String?,
        hasTransformComponent: (Int) -> Boolean,
        getTransformInstance: (Int) -> Int,
        getParentEntity: (Int) -> Int,
    ): String? {
        var currentEntity = entity

        while (currentEntity != 0) {
            val directName = resolveDirectName(currentEntity)
            if (!directName.isNullOrBlank() && directName != "Unnamed Entity") {
                return directName
            }

            if (!hasTransformComponent(currentEntity)) {
                break
            }

            val transformInstance = getTransformInstance(currentEntity)
            if (transformInstance == 0) {
                break
            }

            currentEntity = getParentEntity(transformInstance)
        }

        return null
    }
}
