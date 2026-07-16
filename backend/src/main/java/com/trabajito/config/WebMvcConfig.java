package com.trabajito.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Paths;

/** Sirve los archivos subidos bajo /uploads/**. */
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    private final String uploadsDir;

    public WebMvcConfig(@Value("${trabajito.uploads.dir}") String uploadsDir) {
        this.uploadsDir = uploadsDir;
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        String ruta = Paths.get(uploadsDir).toAbsolutePath().normalize().toUri().toString();
        registry.addResourceHandler("/uploads/**").addResourceLocations(ruta);
    }
}
