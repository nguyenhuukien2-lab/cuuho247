package com.example.roadside.ui.request;

import android.content.Intent;
import android.os.Bundle;
import android.text.TextUtils;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;

import com.example.roadside.R;
import com.example.roadside.ui.providers.ProviderListActivity;

public class RequestFormActivity extends AppCompatActivity {

    private EditText etPlateNumber, etVehicleModel, etLocationNote;
    private Button btnFindTeam;
    private RequestViewModel requestViewModel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_request_form);

        requestViewModel = new ViewModelProvider(this).get(RequestViewModel.class);

        etPlateNumber = findViewById(R.id.etPlateNumber);
        etVehicleModel = findViewById(R.id.etVehicleModel);
        etLocationNote = findViewById(R.id.etLocationNote);
        btnFindTeam = findViewById(R.id.btnFindTeam);

        btnFindTeam.setOnClickListener(v -> {
            String plate = etPlateNumber != null ? etPlateNumber.getText().toString().trim() : "";
            String model = etVehicleModel != null ? etVehicleModel.getText().toString().trim() : "";
            String note = etLocationNote != null ? etLocationNote.getText().toString().trim() : "";

            if (TextUtils.isEmpty(plate)) {
                Toast.makeText(this, "Vui lòng nhập biển kiểm soát xe", Toast.LENGTH_SHORT).show();
                return;
            }

            requestViewModel.createRequest("Cứu hộ nhanh", model + " - " + plate, note);
            Toast.makeText(this, "Đang tìm đội cứu hộ gần nhất...", Toast.LENGTH_SHORT).show();
            startActivity(new Intent(RequestFormActivity.this, ProviderListActivity.class));
            finish();
        });
    }
}
