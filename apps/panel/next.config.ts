import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  transpilePackages: ['@dijigoo/contracts', '@dijigoo/core'],
};

export default nextConfig;
