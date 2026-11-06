package com.shopease.service;

import com.shopease.model.Product;
import com.shopease.repository.ProductRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProductService {

    private final ProductRepository repository;

    public ProductService(ProductRepository repository) {
        this.repository = repository;
    }

    public List<Product> list() {
        return repository.findAll();
    }

    public Product get(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new NotFoundException("Product " + id + " not found"));
    }

    public Product create(Product product) {
        return repository.save(product);
    }

    @Transactional
    public void reduceStock(Long productId, int quantity) {
        Product product = get(productId);
        if (product.getStock() < quantity) {
            throw new BadRequestException("Insufficient stock for " + product.getName());
        }
        product.setStock(product.getStock() - quantity);
        repository.save(product);
    }
}
