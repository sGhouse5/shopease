package com.shopease.web;

import com.shopease.model.Order;
import com.shopease.service.CartService;
import com.shopease.service.CartView;
import com.shopease.service.OrderService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/carts/{cartId}")
public class CartController {

    private final CartService carts;
    private final OrderService orders;

    public CartController(CartService carts, OrderService orders) {
        this.carts = carts;
        this.orders = orders;
    }

    @GetMapping
    public CartView view(@PathVariable String cartId) {
        return carts.view(cartId);
    }

    @PostMapping("/items")
    public CartView addItem(@PathVariable String cartId, @Valid @RequestBody AddItemRequest request) {
        return carts.addItem(cartId, request.productId(), request.quantity());
    }

    @PostMapping("/checkout")
    @ResponseStatus(HttpStatus.CREATED)
    public Order checkout(@PathVariable String cartId, @Valid @RequestBody CheckoutRequest request) {
        return orders.checkout(cartId, request.customerName());
    }
}
