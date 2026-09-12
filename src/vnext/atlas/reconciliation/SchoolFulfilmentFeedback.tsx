import { Box, Button, Flex, Text } from "@chakra-ui/react";
import { schoolDispatchBlockerLabel } from "../bridges/schoolDispatch";
function schoolFulfilmentBlockerLabel(code: string) {
  return code === "PXK_REPLACEMENT_REQUIRED"
    ? "Phiếu xuất kho cần được thay thế để khớp với dữ liệu hiện tại."
    : schoolDispatchBlockerLabel(code);
}
export function OperationalSignals({
  blockers,
  warnings,
}: {
  blockers: string[];
  warnings: string[];
}) {
  if (!blockers.length && !warnings.length) return null;
  return (
    <Box textStyle="helper" py="sm">
      {blockers.length > 0 && (
        <Box mb="xs">
          <Text fontWeight="semibold" color="status.danger">
            Vướng mắc vận hành
          </Text>
          {blockers.map((code, i) => (
            <Text key={`${code}:${i}`}>
              {schoolFulfilmentBlockerLabel(code)}
            </Text>
          ))}
        </Box>
      )}
      {warnings.length > 0 && (
        <Box>
          <Text fontWeight="semibold" color="status.warning">
            Lưu ý vận hành
          </Text>
          <Text>Dữ liệu nguồn có lưu ý cần kiểm tra.</Text>
        </Box>
      )}
    </Box>
  );
}
export function SchoolFulfilmentFeedback({
  error,
  loading,
  onRetry,
}: {
  error: string | null;
  loading: boolean;
  onRetry: () => void;
}) {
  if (!error) return null;
  return (
    <Flex p="md" gap="sm" align="center" wrap="wrap" bg="bg.danger">
      <Text role="alert" color="status.danger">
        {error}
      </Text>
      <Button disabled={loading} onClick={onRetry}>
        Thử tải lại dữ liệu
      </Button>
    </Flex>
  );
}
