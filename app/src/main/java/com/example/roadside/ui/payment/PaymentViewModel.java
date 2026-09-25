package com.example.roadside.ui.payment;

import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;
import androidx.lifecycle.ViewModel;

import com.example.roadside.data.models.Payment;
import com.example.roadside.data.repository.PaymentRepository;

public class PaymentViewModel extends ViewModel {

    private final PaymentRepository paymentRepository;
    private final MutableLiveData<Payment> paymentResult = new MutableLiveData<>();

    public PaymentViewModel() {
        paymentRepository = new PaymentRepository();
    }

    public LiveData<Payment> getPaymentResult() {
        return paymentResult;
    }

    public void processPayment(int requestId, double amount, String paymentMethod) {
        Payment payment = paymentRepository.processPayment(requestId, amount, paymentMethod);
        paymentResult.setValue(payment);
    }
}
