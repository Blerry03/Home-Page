import 'server-only';
import { createClient } from '@supabase/supabase-js';
import { createCipheriv, createDecipheriv, createHmac, createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import type { NextRequest } from 'next/server';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const googleId = process.env.GOOGLE_CLIENT_ID;
const googleSecret = process.env.GOOGLE_CLIENT_SECRET;
const baseUrl = process.env.APP_BASE_URL;
const encryptionSecret = process.env.GOOGLE_TOKEN_ENCRYPTION_KEY;
export const googleReady = Boolean(url && serviceKey && googleId && googleSecret && baseUrl && encryptionSecret);

export function admin(){
 if (!url || !serviceKey) throw new Error('Supabase server credentials are missing');
 return createClient(url, serviceKey, { auth:{ persistSession:false, autoRefreshToken:false } });
}
export async function authenticate(req:NextRequest){
 const bearer=req.headers.get('authorization');
 if(!bearer?.startsWith('Bearer '))throw new Error('Sign in to HQ to use calendar sync');
 const db=admin();
 const {data:{user},error}=await db.auth.getUser(bearer.slice(7));
 if(error||!user)throw new Error('Your HQ session expired. Please sign in again.');
 const {data:org,error:orgError}=await db.from('organizations').select('id').eq('owner_id',user.id).single();
 if(orgError||!org)throw new Error('No Just The Guy organization found');
 return {db,user,orgId:org.id as string};
}
function key(){if(!encryptionSecret)throw new Error('Google token encryption key missing');return createHash('sha256').update(encryptionSecret).digest();}
export function encrypt(plain:string){const nonce=randomBytes(12);const cipher=createCipheriv('aes-256-gcm',key(),nonce);const encrypted=Buffer.concat([cipher.update(plain,'utf8'),cipher.final()]);return Buffer.concat([nonce,cipher.getAuthTag(),encrypted]).toString('base64');}
export function decrypt(value:string){const all=Buffer.from(value,'base64');const d=createDecipheriv('aes-256-gcm',key(),all.subarray(0,12));d.setAuthTag(all.subarray(12,28));return Buffer.concat([d.update(all.subarray(28)),d.final()]).toString('utf8');}
export function createState(userId:string){const payload=Buffer.from(JSON.stringify({userId,ts:Date.now(),nonce:randomBytes(12).toString('hex')})).toString('base64url');const signature=createHmac('sha256',key()).update(payload).digest('base64url');return `${payload}.${signature}`;}
export function verifyState(state:string):string{
 const [payload,signature]=state.split('.');if(!payload||!signature)throw new Error('Google connection state missing');
 const expected=createHmac('sha256',key()).update(payload).digest();const actual=Buffer.from(signature,'base64url');
 if(actual.length!==expected.length||!timingSafeEqual(expected,actual))throw new Error('Invalid Google connection state');
 const decoded=JSON.parse(Buffer.from(payload,'base64url').toString());
 if(typeof decoded.userId!=='string'||typeof decoded.ts!=='number'||Date.now()-decoded.ts>10*60*1000||decoded.ts>Date.now()+60000)throw new Error('Expired Google connection state');
 return decoded.userId;
}
export function callbackUri(){if(!baseUrl)throw new Error('APP_BASE_URL missing');return new URL('/api/google/callback',baseUrl).toString();}
export function oauthUrl(state:string){if(!googleId)throw new Error('GOOGLE_CLIENT_ID missing');const params=new URLSearchParams({client_id:googleId,redirect_uri:callbackUri(),response_type:'code',scope:'https://www.googleapis.com/auth/calendar.events',access_type:'offline',prompt:'consent',state});return 'https://accounts.google.com/o/oauth2/v2/auth?'+params.toString();}
export async function tokenRequest(params:URLSearchParams){if(!googleId||!googleSecret)throw new Error('Google OAuth settings missing');params.set('client_id',googleId);params.set('client_secret',googleSecret);const res=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:params.toString(),cache:'no-store'});const data=await res.json();if(!res.ok||!data.access_token)throw new Error(data.error_description||data.error||'Google token exchange failed');return data as {access_token:string;refresh_token?:string;expires_in?:number};}
export async function googleApi(path:string,token:string,method:string,body?:unknown){return fetch('https://www.googleapis.com/calendar/v3/'+path,{method,headers:{Authorization:'Bearer '+token,...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,cache:'no-store'});}
export function nextDate(ymd:string){const date=new Date(ymd+'T12:00:00Z');date.setUTCDate(date.getUTCDate()+1);return date.toISOString().slice(0,10);}
