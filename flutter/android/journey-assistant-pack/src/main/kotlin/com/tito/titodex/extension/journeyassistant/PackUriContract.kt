package com.tito.titodex.extension.journeyassistant

import java.io.FileNotFoundException

internal data class PackResource(
    val assetPath: String,
    val displayName: String,
    val mediaType: String,
)

internal object PackUriContract {
    const val AUTHORITY = "com.tito.titodex.extension.journeyassistant.provider"

    private val manifest = PackResource(
        assetPath = "extension_manifest.json",
        displayName = "extension_manifest.json",
        mediaType = "application/vnd.titodex.extension-manifest+json",
    )
    private val files = mapOf(
        "progression_hints.json" to PackResource(
            assetPath = "progression_hints.json",
            displayName = "progression_hints.json",
            mediaType = "application/json",
        ),
    )

    fun resolve(authority: String?, pathSegments: List<String>, mode: String): PackResource {
        if (authority != AUTHORITY) {
            throw FileNotFoundException("Unknown pack authority")
        }
        if (mode != "r") {
            throw FileNotFoundException("Journey Assistant pack is read-only")
        }

        return when {
            pathSegments == listOf("manifest") -> manifest
            pathSegments.size == 2 && pathSegments[0] == "files" ->
                files[pathSegments[1]] ?: throw FileNotFoundException("Unknown pack file")
            else -> throw FileNotFoundException("Unknown pack URI")
        }
    }
}
