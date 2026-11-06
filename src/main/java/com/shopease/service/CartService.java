package com.shopease.service;

import com.shopease.model.Product;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;

/**
 * In-memory carts keyed by a client-supplied cart id.
 * Good enough for the demo; carts are lost on restart (see docs/adr/0004-in-memory-carts.md).
 */
@Service
public class CartService {

    private final Map<String, Map<Long, Integer>> carts = new ConcurrentHashMap<>();
    private final ProductService products;

    public CartService(ProductService products) {
        this.products = products;
    }

    public CartView addItem(String cartId, Long productId, int quantity) {
        products.get(productId); // throws NotFoundException for unknown products
        carts.computeIfAbsent(cartId, id -> new ConcurrentHashMap<>())
                .merge(productId, quantity, Integer::sum);
        return view(cartId);
    }

    public CartView view(String cartId) {
        Map<Long, Integer> items = carts.getOrDefault(cartId, Map.of());
        List<CartLine> lines = new ArrayList<>();
        BigDecimal total = BigDecimal.ZERO;
        for (Map.Entry<Long, Integer> entry : items.entrySet()) {
            Product product = products.get(entry.getKey());
            BigDecimal lineTotal = product.getPrice().multiply(BigDecimal.valueOf(entry.getValue()));
            lines.add(new CartLine(product.getId(), product.getName(), product.getPrice(),
                    entry.getValue(), lineTotal));
            total = total.add(lineTotal);
        }
        return new CartView(cartId, lines, total);
    }

    public void clear(String cartId) {
        carts.remove(cartId);
    }
}
