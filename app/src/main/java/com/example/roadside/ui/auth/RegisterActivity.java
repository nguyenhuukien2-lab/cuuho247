package com.example.roadside.ui.auth;

import android.content.Intent;
import android.os.Bundle;
import android.text.TextUtils;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;

import com.example.roadside.R;
import com.example.roadside.ui.home.HomeActivity;

public class RegisterActivity extends AppCompatActivity {

    private EditText etFullName, etEmail, etPhone, etPassword, etConfirmPassword;
    private Button btnRegister;
    private TextView tvLogin;
    private AuthViewModel authViewModel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_register);

        authViewModel = new ViewModelProvider(this).get(AuthViewModel.class);

        etFullName = findViewById(R.id.etFullName);
        etEmail = findViewById(R.id.etEmail);
        etPhone = findViewById(R.id.etPhone);
        etPassword = findViewById(R.id.etPassword);
        etConfirmPassword = findViewById(R.id.etConfirmPassword);
        btnRegister = findViewById(R.id.btnRegister);
        tvLogin = findViewById(R.id.tvLogin);

        btnRegister.setOnClickListener(v -> {
            String name = etFullName.getText().toString().trim();
            String email = etEmail.getText().toString().trim();
            String phone = etPhone.getText().toString().trim();
            String password = etPassword.getText().toString().trim();
            String confirmPassword = etConfirmPassword.getText().toString().trim();

            if (TextUtils.isEmpty(name) || TextUtils.isEmpty(email) || TextUtils.isEmpty(password)) {
                Toast.makeText(this, "Vui lòng nhập đầy đủ thông tin", Toast.LENGTH_SHORT).show();
                return;
            }

            if (!password.equals(confirmPassword)) {
                Toast.makeText(this, "Mật khẩu xác nhận không khớp", Toast.LENGTH_SHORT).show();
                return;
            }

            authViewModel.register(name, email, phone, password);
        });

        authViewModel.getRegisterResult().observe(this, success -> {
            if (Boolean.TRUE.equals(success)) {
                Toast.makeText(this, "Đăng ký thành công!", Toast.LENGTH_SHORT).show();
                startActivity(new Intent(RegisterActivity.this, HomeActivity.class));
                finish();
            } else {
                Toast.makeText(this, "Email đã tồn tại hoặc đăng ký thất bại", Toast.LENGTH_SHORT).show();
            }
        });

        tvLogin.setOnClickListener(v -> finish());
    }
}
