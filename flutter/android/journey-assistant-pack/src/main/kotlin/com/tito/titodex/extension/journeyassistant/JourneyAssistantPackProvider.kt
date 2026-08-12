package com.tito.titodex.extension.journeyassistant

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.FileNotFoundException

class JourneyAssistantPackProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String = resolve(uri).mediaType

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val resource = resolve(uri)
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val size = requireNotNull(context).assets.open(resource.assetPath).use { input ->
            var count = 0L
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                count += read
            }
            count
        }
        return MatrixCursor(columns, 1).apply {
            newRow().also { row ->
                columns.forEach { column ->
                    row.add(
                        when (column) {
                            OpenableColumns.DISPLAY_NAME -> resource.displayName
                            OpenableColumns.SIZE -> size
                            else -> null
                        },
                    )
                }
            }
        }
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        val resource = PackUriContract.resolve(uri.authority, uri.pathSegments, mode)
        return openPipeHelper(
            uri,
            resource.mediaType,
            Bundle.EMPTY,
            resource.assetPath,
        ) { output, _, _, _, assetPath ->
            ParcelFileDescriptor.AutoCloseOutputStream(output).use { destination ->
                requireNotNull(context).assets.open(requireNotNull(assetPath)).use { source ->
                    source.copyTo(destination)
                }
            }
        }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri = readOnly()

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = readOnly()

    override fun delete(
        uri: Uri,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = readOnly()

    private fun resolve(uri: Uri): PackResource =
        PackUriContract.resolve(uri.authority, uri.pathSegments, "r")

    private fun <T> readOnly(): T {
        throw UnsupportedOperationException("Journey Assistant pack is read-only")
    }
}
