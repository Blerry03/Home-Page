import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'Just The Guy HQ', description: 'Private business management for Just The Guy Gutters & Exteriors' };
export default function Layout({ children }: { children: React.ReactNode }) { return <html lang="en"><body>{children}</body></html>; }
