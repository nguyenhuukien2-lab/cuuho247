package com.example.roadside.ui.payment;

import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;

import com.example.roadside.R;
import com.example.roadside.ui.home.HomeActivity;
import com.example.roadside.utils.PaymentHelper;

public class PaymentActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_payment);

        int requestId = getIntent().getIntExtra("request_id", 1);
        double amount = getIntent().getDoubleExtra("amount", 170000.0);

        TextView tvTotalAmount = findViewById(R.id.tvTotalAmount);
        RadioGroup rgPaymentMethod = findViewById(R.id.rgPaymentMethod);
        Button btnConfirmPayment = findViewById(R.id.btnConfirmPayment);

        if (tvTotalAmount != null) {
            tvTotalAmount.setText(PaymentHelper.formatCurrency(amount));
        }

        PaymentViewModel viewModel = new ViewModelProvider(this).get(PaymentViewModel.class);

        if (btnConfirmPayment != null) {
            btnConfirmPayment.setOnClickListener(v -> {
                String method = "Tiền mặt";
                if (rgPaymentMethod != null) {
                    int selectedId = rgPaymentMethod.getCheckedRadioButtonId();
                    RadioButton selectedRb = findViewById(selectedId);
                    if (selectedRb != null) {
                        method = selectedRb.getText().toString();
                    }
                }

                viewModel.processPayment(requestId, amount, method);
                Toast.makeText(this, "Thanh toán thành công qua " + method, Toast.LENGTH_LONG).show();
                Intent intent = new Intent(PaymentActivity.this, HomeActivity.class);
                intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
                startActivity(intent);
                finish();
            });
        }
    }
}
