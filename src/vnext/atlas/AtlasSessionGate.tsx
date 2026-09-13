import {
  Box,
  Button,
  Field,
  Heading,
  Input,
  Stack,
  Text,
} from "@chakra-ui/react";
import { useState, type ReactNode } from "react";

export type AtlasSessionModel = {
  status:
    | "configuration_error"
    | "loading"
    | "unauthenticated"
    | "authenticated"
    | "session_expired";
  safeMessage?: string;
};
export function AtlasSessionGate({
  session,
  onSignIn,
  safeAuthError,
  children,
}: {
  session: AtlasSessionModel;
  onSignIn: (email: string, password: string) => Promise<boolean>;
  safeAuthError?: string | null;
  children: ReactNode;
}) {
  if (session.status === "authenticated") return children;
  return (
    <Box
      as="main"
      minH="var(--atlas-layout-viewport-height, 100dvh)"
      bg="bg.workspace"
      p="lg"
    >
      <Box
        maxW="var(--atlas-layout-signin-width, 400px)"
        mx="var(--atlas-layout-auto, auto)"
        mt="lg"
        p="lg"
        bg="bg.workbench"
        borderRadius="workbench"
      >
        <Heading as="h1" textStyle="workbenchTitle">
          Atlas
        </Heading>
        <Text textStyle="helper" color="fg.muted" mt="xs">
          Vận hành trường học
        </Text>
        {session.status === "loading" ||
        session.status === "configuration_error" ? (
          <Text role="status" mt="md">
            {session.status === "loading"
              ? "Đang kiểm tra phiên làm việc…"
              : "Chưa thể kết nối ứng dụng. Vui lòng liên hệ người phụ trách."}
          </Text>
        ) : (
          <SignIn
            onSignIn={onSignIn}
            message={
              session.status === "session_expired"
                ? (session.safeMessage ??
                  "Phiên làm việc đã hết hoặc không còn hợp lệ. Vui lòng đăng nhập lại trước khi tiếp tục.")
                : undefined
            }
            safeAuthError={safeAuthError}
          />
        )}
      </Box>
    </Box>
  );
}
function SignIn({
  onSignIn,
  message,
  safeAuthError,
}: {
  onSignIn: (email: string, password: string) => Promise<boolean>;
  message?: string;
  safeAuthError?: string | null;
}) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(false);
  return (
    <form
      onSubmit={async (event) => {
        event.preventDefault();
        if (busy) return;
        setBusy(true);
        setError(false);
        try {
          await onSignIn(email.trim(), password);
        } catch {
          setError(true);
        } finally {
          setPassword("");
          setBusy(false);
        }
      }}
    >
      <Stack gap="md" mt="md">
        {message && <Text role="alert">{message}</Text>}
        {(safeAuthError || error) && (
          <Text role="alert" color="status.danger">
            {safeAuthError ?? "Không thể đăng nhập. Vui lòng thử lại."}
          </Text>
        )}
        <Field.Root>
          <Field.Label htmlFor="atlas-signin-email">Email</Field.Label>
          <Input
            id="atlas-signin-email"
            type="email"
            autoComplete="username"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </Field.Root>
        <Field.Root>
          <Field.Label htmlFor="atlas-signin-password">Mật khẩu</Field.Label>
          <Input
            id="atlas-signin-password"
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </Field.Root>
        <Button type="submit" variant="businessPrimary" loading={busy}>
          Đăng nhập
        </Button>
      </Stack>
    </form>
  );
}
