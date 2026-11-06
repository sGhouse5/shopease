package com.shopease.web;

import jakarta.validation.constraints.NotBlank;

public record CheckoutRequest(@NotBlank String customerName) {
}
