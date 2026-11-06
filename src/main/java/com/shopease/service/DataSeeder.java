package com.shopease.service;

import com.shopease.model.Product;
import com.shopease.repository.ProductRepository;
import java.math.BigDecimal;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/** Adds a few demo products on first start, only when the table is empty. */
@Component
@ConditionalOnProperty(name = "shop.seed-data", havingValue = "true", matchIfMissing = true)
public class DataSeeder implements CommandLineRunner {

    private final ProductRepository repository;

    public DataSeeder(ProductRepository repository) {
        this.repository = repository;
    }

    @Override
    public void run(String... args) {
        if (repository.count() > 0) {
            return;
        }
        repository.save(new Product("Wireless Mouse", "2.4 GHz optical mouse", new BigDecimal("14.99"), 50));
        repository.save(new Product("Mechanical Keyboard", "Blue switches, USB", new BigDecimal("49.90"), 25));
        repository.save(new Product("USB-C Hub", "6-in-1 hub with HDMI", new BigDecimal("29.50"), 40));
        repository.save(new Product("Laptop Stand", "Aluminium, adjustable", new BigDecimal("22.00"), 30));
        repository.save(new Product("Notebook (A5)", "200 pages, ruled", new BigDecimal("3.50"), 200));
    }
}
