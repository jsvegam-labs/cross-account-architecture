package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class DemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }

    @GetMapping("/")
    public String hello() {
        return "¡Hola! Pipeline CI/CD funcionando con Trivy + ArgoCD + EKS 🚀";
    }

    @GetMapping("/health")
    public String health() {
        return "OK - App Java funcionando correctamente";
    }
}