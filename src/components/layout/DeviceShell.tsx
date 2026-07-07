import type { ReactNode } from 'react';
import { StatusBar } from './StatusBar';

type DeviceShellProps = {
  children: ReactNode;
};

export function DeviceShell({ children }: DeviceShellProps) {
  return (
    <div className="device-shell">
      <div className="device-shell__bezel">
        <StatusBar />
        <div className="device-shell__screen">{children}</div>
      </div>
    </div>
  );
}
