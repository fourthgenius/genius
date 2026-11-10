/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    // Event posters and Spotify artist images come from arbitrary hosts (MVP).
    remotePatterns: [{ protocol: "https", hostname: "**" }],
  },
};

export default nextConfig;
