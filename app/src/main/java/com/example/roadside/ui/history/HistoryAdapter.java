package com.example.roadside.ui.history;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;

import com.example.roadside.R;
import com.example.roadside.data.models.Request;
import com.example.roadside.utils.PaymentHelper;

import java.util.ArrayList;
import java.util.List;

public class HistoryAdapter extends RecyclerView.Adapter<HistoryAdapter.ViewHolder> {

    private List<Request> requestList = new ArrayList<>();

    public void setRequests(List<Request> requests) {
        this.requestList = requests != null ? requests : new ArrayList<>();
        notifyDataSetChanged();
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_request, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        Request request = requestList.get(position);
        if (holder.tvRequestService != null) {
            holder.tvRequestService.setText(request.getServiceType());
        }
        if (holder.tvRequestDate != null) {
            holder.tvRequestDate.setText("Mã YC: #" + request.getId());
        }
        if (holder.tvRequestStatus != null) {
            holder.tvRequestStatus.setText(request.getStatus());
        }
        if (holder.tvRequestCost != null) {
            holder.tvRequestCost.setText(PaymentHelper.formatCurrency(request.getCost()));
        }
        if (holder.btnRebook != null) {
            holder.btnRebook.setOnClickListener(v -> Toast.makeText(v.getContext(), "Đặt lại dịch vụ thành công!", Toast.LENGTH_SHORT).show());
        }
        if (holder.btnInvoice != null) {
            holder.btnInvoice.setOnClickListener(v -> Toast.makeText(v.getContext(), "Đang tải hóa đơn điện tử...", Toast.LENGTH_SHORT).show());
        }
    }

    @Override
    public int getItemCount() {
        return requestList.size();
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        TextView tvRequestService, tvRequestDate, tvRequestStatus, tvRequestVehicle, tvRequestLocation, tvRequestCost, tvRequestRating, btnInvoice, btnRebook;

        public ViewHolder(@NonNull View itemView) {
            super(itemView);
            tvRequestService = itemView.findViewById(R.id.tvRequestService);
            tvRequestDate = itemView.findViewById(R.id.tvRequestDate);
            tvRequestStatus = itemView.findViewById(R.id.tvRequestStatus);
            tvRequestVehicle = itemView.findViewById(R.id.tvRequestVehicle);
            tvRequestLocation = itemView.findViewById(R.id.tvRequestLocation);
            tvRequestCost = itemView.findViewById(R.id.tvRequestCost);
            tvRequestRating = itemView.findViewById(R.id.tvRequestRating);
            btnInvoice = itemView.findViewById(R.id.btnEInvoice);
            btnRebook = itemView.findViewById(R.id.btnRebookProvider);
        }
    }
}
