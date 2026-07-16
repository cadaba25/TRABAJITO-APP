package com.trabajito.modules.archivos;

import com.trabajito.common.exception.ApiException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.UUID;

/**
 * Subida de archivos (fotos de perfil, evidencias). Se guardan en la carpeta
 * local configurada y en la BD solo se persiste la ruta devuelta aquí.
 *
 * <p>NOTA: para escalar, migrar a almacenamiento de objetos (S3/MinIO).
 */
@RestController
@RequestMapping("/api/archivos")
public class ArchivoController {

    private final Path dir;

    public ArchivoController(@Value("${trabajito.uploads.dir}") String uploadsDir) {
        this.dir = Paths.get(uploadsDir).toAbsolutePath().normalize();
    }

    @PostMapping
    public Map<String, String> subir(@RequestParam("archivo") MultipartFile archivo) {
        if (archivo.isEmpty()) throw ApiException.solicitudInvalida("Archivo vacío");
        try {
            Files.createDirectories(dir);
            String original = archivo.getOriginalFilename() == null ? "archivo"
                    : archivo.getOriginalFilename().replaceAll("[^a-zA-Z0-9._-]", "_");
            String nombre = UUID.randomUUID() + "_" + original;
            Path destino = dir.resolve(nombre);
            // Evita path traversal.
            if (!destino.getParent().equals(dir)) {
                throw ApiException.solicitudInvalida("Nombre de archivo inválido");
            }
            archivo.transferTo(destino);
            return Map.of("url", "/uploads/" + nombre);
        } catch (IOException e) {
            throw ApiException.solicitudInvalida("No se pudo guardar el archivo");
        }
    }
}
