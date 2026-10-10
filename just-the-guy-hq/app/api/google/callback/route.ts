import { NextRequest,NextResponse } from 'next/server';
import { admin,callbackUri,encrypt,googleReady,tokenRequest,verifyState } from '../../../../lib/google-server';
export const runtime='nodejs';
export async function GET(req:NextRequest){
 const target=new URL('/',process.env.APP_BASE_URL||req.nextUrl.origin);
 try{
  if(!googleReady)throw new Error('Google integration is not configured');
  const denied=req.nextUrl.searchParams.get('error');if(denied)throw new Error('Google authorization was cancelled: '+denied);
  const code=req.nextUrl.searchParams.get('code');const state=req.nextUrl.searchParams.get('state');if(!code||!state)throw new Error('Missing Google authorization details');
  const userId=verifyState(state);
  const tokens=await tokenRequest(new URLSearchParams({grant_type:'authorization_code',code,redirect_uri:callbackUri()}));
  const db=admin();const {data:owner,error:ownerError}=await db.from('organizations').select('id').eq('owner_id',userId).single();if(ownerError||!owner)throw new Error('Organization not found');
  const {data:existing}=await db.from('google_calendar_connections').select('refresh_token_ciphertext').eq('user_id',userId).maybeSingle();
  const encrypted=tokens.refresh_token?encrypt(tokens.refresh_token):existing?.refresh_token_ciphertext;
  if(!encrypted)throw new Error('Google did not provide a refresh token. Disconnect HQ from Google and retry.');
  const {error}=await db.from('google_calendar_connections').upsert({user_id:userId,organization_id:owner.id,refresh_token_ciphertext:encrypted,updated_at:new Date().toISOString()},{onConflict:'user_id'});
  if(error)throw new Error(error.message);
  target.searchParams.set('google','connected');
 }catch(e){target.searchParams.set('google_error',e instanceof Error?e.message:'Unable to connect Google');}
 return NextResponse.redirect(target);
}
