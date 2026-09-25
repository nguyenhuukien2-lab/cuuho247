package com.example.roadside.data.repository;

import com.example.roadside.data.models.Payment;

import java.util.UUID;

public class PaymentRepository {

    public Payment processPayment(int requestId, double amount, String paymentMethod) {
        Payment payment = new Payment();
        payment.setId((int) (System.currentTimeMillis() % 100000));
        payment.setRequestId(requestId);
        payment.setAmount(amount);
        payment.setPaymentMethod(paymentMethod);
        payment.setPaymentStatus("SUCCESS");
        payment.setTransactionId("TXN-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase());
        payment.setTimestamp(String.valueOf(System.currentTimeMillis()));
        return payment;
    }
}
