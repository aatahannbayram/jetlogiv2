import { identityResponse } from '@/lib/identity';

export async function GET(request: Request) {
  return identityResponse(request, 'availability');
}
