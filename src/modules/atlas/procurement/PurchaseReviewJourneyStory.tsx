import { useEffect, useState } from "react";
import {
  seedReviewPurchaseJourney,
  type ReviewPurchasePhase,
} from "./reviewPurchaseReviewApi";
import { GeneratedPurchaseReview } from "./GeneratedPurchaseReview";
import { SchoolCateringProcurementWorkbench } from "./SchoolCateringProcurementWorkbench";
import { ConfirmedNeedReviewWorkbench } from "../planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench";
import {
  PlanningRailActionHost,
  PlanningRailActionProvider,
} from "../planning-inputs/PlanningRailActionPortal";
import { createReviewAuthState } from "../review/reviewMode";

export function PurchaseReviewJourneyStory({
  phase = "generated",
  planning = false,
  fault,
}: {
  phase?: ReviewPurchasePhase;
  planning?: boolean;
  fault?: "unknown" | "retryable";
}) {
  const [journey, setJourney] =
    useState<Awaited<ReturnType<typeof seedReviewPurchaseJourney>>>();
  const [allocation, setAllocation] = useState(
    !planning && !["generated", "confirmed"].includes(phase),
  );
  useEffect(() => {
    let current = true;
    void seedReviewPurchaseJourney(phase).then((next) => {
      if (fault)
        next.purchaseReviewApi.preparePurchaseOrders = async () =>
          fault === "unknown"
            ? {
                kind: "transport_error",
                diagnostic: {
                  code: "NETWORK_FAILURE",
                  safeMessage: "Chưa xác định kết quả chuẩn bị đơn mua.",
                },
              }
            : {
                kind: "backend_error",
                error: {
                  success: false,
                  error_code: "RETRYABLE_CONCURRENCY_FAILURE",
                  safe_message:
                    "Chưa thể khóa nguồn hiện hành. Có thể thử lại cùng yêu cầu.",
                  retryable: true,
                },
              };
      if (current) setJourney(next);
    });
    return () => {
      current = false;
    };
  }, [phase, fault]);
  if (!journey) return <p role="status">Đang chuẩn bị dữ liệu xem thử…</p>;
  return (
    <PlanningRailActionProvider>
      <main className="atlas-page">
        <p className="procurement-supporting-note">
          Xem thử tổng hợp · Không lưu dữ liệu vận hành · 03/09/2026
        </p>
        {allocation ? (
          <SchoolCateringProcurementWorkbench
            api={journey.procurementApi}
            purchaseReviewApi={journey.purchaseReviewApi}
            authState={createReviewAuthState("ready")}
            initialDateStart="2026-09-03"
            initialDateEnd="2026-09-03"
            initialStage={
              ["prepared", "released"].includes(phase) ? "orders" : "allocation"
            }
            mode="review"
          />
        ) : (
          <>
            <PlanningRailActionHost />
            <GeneratedPurchaseReview
              api={journey.purchaseReviewApi}
              authSubject="review"
              serviceDate="2026-09-03"
            />
            <ConfirmedNeedReviewWorkbench
              api={journey.confirmedNeedApi}
              authState={createReviewAuthState("ready")}
              initialBatchId={journey.inspect().need.confirmed_need_batch_id}
              workingServiceDate="2026-09-03"
              onContinueAllocation={() => setAllocation(true)}
              mode="review"
            />
          </>
        )}
      </main>
    </PlanningRailActionProvider>
  );
}
