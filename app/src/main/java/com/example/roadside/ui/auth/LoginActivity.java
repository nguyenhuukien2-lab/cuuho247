package com.example.roadside.ui.auth;

import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

import com.example.roadside.R;
import com.example.roadside.ui.home.HomeActivity;

public class LoginActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_login);

        EditText etEmail = findViewById(R.id.etEmail);
        EditText etPassword = findViewById(R.id.etPassword);
        Button btnLogin = findViewById(R.id.btnLogin);
        TextView tvRegister = findViewById(R.id.tvRegister);

        btnLogin.setOnClickListener(v -> {
            Toast.makeText(this, "Đăng nhập thành công!", Toast.LENGTH_SHORT).show();
            startActivity(new Intent(LoginActivity.this, HomeActivity.class));
            finish();
        });

        tvRegister.setOnClickListener(v -> {
            startActivity(new Intent(LoginActivity.this, RegisterActivity.class));
        });
    }
}
