import { Capacitor } from '@capacitor/core';

export const isNativePlatform = (): boolean => Capacitor.isNativePlatform();

export const getPlatform = (): string => Capacitor.getPlatform();
