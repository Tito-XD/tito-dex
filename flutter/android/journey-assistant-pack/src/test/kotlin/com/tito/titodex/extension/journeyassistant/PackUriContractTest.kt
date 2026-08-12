package com.tito.titodex.extension.journeyassistant

import java.io.FileNotFoundException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class PackUriContractTest {
    @Test
    fun resolvesManifestAndKnownPayload() {
        val manifest = PackUriContract.resolve(
            PackUriContract.AUTHORITY,
            listOf("manifest"),
            "r",
        )
        val payload = PackUriContract.resolve(
            PackUriContract.AUTHORITY,
            listOf("files", "progression_hints.json"),
            "r",
        )

        assertEquals("extension_manifest.json", manifest.assetPath)
        assertEquals("progression_hints.json", payload.assetPath)
    }

    @Test
    fun rejectsForeignAuthorityAndUnknownFiles() {
        assertThrows(FileNotFoundException::class.java) {
            PackUriContract.resolve("other.provider", listOf("manifest"), "r")
        }
        assertThrows(FileNotFoundException::class.java) {
            PackUriContract.resolve(
                PackUriContract.AUTHORITY,
                listOf("files", "unknown.json"),
                "r",
            )
        }
    }

    @Test
    fun rejectsTraversalAndExtraPathSegments() {
        listOf(
            listOf("files", "../progression_hints.json"),
            listOf("files", "..", "progression_hints.json"),
            listOf("files", "progression_hints.json", "extra"),
        ).forEach { segments ->
            assertThrows(FileNotFoundException::class.java) {
                PackUriContract.resolve(PackUriContract.AUTHORITY, segments, "r")
            }
        }
    }

    @Test
    fun rejectsEveryWriteMode() {
        listOf("w", "wt", "wa", "rw", "rwt").forEach { mode ->
            assertThrows(FileNotFoundException::class.java) {
                PackUriContract.resolve(PackUriContract.AUTHORITY, listOf("manifest"), mode)
            }
        }
    }
}
