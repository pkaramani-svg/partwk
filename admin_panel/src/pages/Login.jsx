import React, { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Lock, Mail, ShieldCheck, ArrowRight, AlertCircle, KeyRound, Hash } from 'lucide-react';
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import './Login.css';

// Pure JS TOTP calculation algorithm for Google Authenticator
async function verifyTOTP(token, secret = 'PARTWKADMINSECRET2FA') {
  try {
    const base32chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    let bits = '';
    for (let i = 0; i < secret.length; i++) {
      const val = base32chars.indexOf(secret.charAt(i).toUpperCase());
      if (val >= 0) bits += val.toString(2).padStart(5, '0');
    }
    const bytes = new Uint8Array(Math.floor(bits.length / 8));
    for (let i = 0; i < bytes.length; i++) {
      bytes[i] = parseInt(bits.substr(i * 8, 8), 2);
    }

    const currentEpoch = Math.floor(Date.now() / 1000 / 30);
    for (let timeOffset = -1; timeOffset <= 1; timeOffset++) {
      const epoch = currentEpoch + timeOffset;
      const timeBuffer = new ArrayBuffer(8);
      const timeView = new DataView(timeBuffer);
      timeView.setBigInt64(0, BigInt(epoch), false);

      const key = await window.crypto.subtle.importKey(
        'raw',
        bytes,
        { name: 'HMAC', hash: 'SHA-1' },
        false,
        ['sign']
      );
      const signature = await window.crypto.subtle.sign('HMAC', key, timeBuffer);
      const sigView = new DataView(signature);
      const offset = sigView.getUint8(signature.byteLength - 1) & 0xf;
      const binary = (sigView.getUint32(offset) & 0x7fffffff) % 1000000;
      const calculatedToken = binary.toString().padStart(6, '0');

      if (calculatedToken === token) {
        return true;
      }
    }
  } catch (e) {
    console.error("TOTP verification error:", e);
  }
  return false;
}

const Login = () => {
  const navigate = useNavigate();
  const [step, setStep] = useState(1); // 1: Credentials, 2: Google Authenticator 2FA
  
  // Step 1 State
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Step 2 State (6-digit OTP & Dual Emergency Backup)
  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [useEmergencyCode, setUseEmergencyCode] = useState(false);
  const [emergencyKey, setEmergencyKey] = useState('');
  const [emergencyPin, setEmergencyPin] = useState('');
  const inputRefs = useRef([]);

  const handleStep1Submit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    const cleanEmail = email.trim().toLowerCase();

    // Enforce pkaramani@gmail.com as sole admin
    if (cleanEmail !== 'pkaramani@gmail.com') {
      setError("Access denied. Invalid administrator credentials.");
      setLoading(false);
      return;
    }

    try {
      const auth = getAuth();
      const userCred = await signInWithEmailAndPassword(auth, cleanEmail, password);
      if (userCred.user) {
        setStep(2);
        setTimeout(() => {
          if (inputRefs.current[0]) inputRefs.current[0].focus();
        }, 100);
      }
    } catch (authErr) {
      console.error("Auth error:", authErr);
      setError("Access denied. Invalid administrator credentials.");
    } finally {
      setLoading(false);
    }
  };

  const handleOtpChange = (index, value) => {
    if (isNaN(value)) return;
    const newOtp = [...otp];
    newOtp[index] = value.substring(value.length - 1);
    setOtp(newOtp);

    if (value && index < 5 && inputRefs.current[index + 1]) {
      inputRefs.current[index + 1].focus();
    }
  };

  const handleKeyDown = (index, e) => {
    if (e.key === 'Backspace' && !otp[index] && index > 0 && inputRefs.current[index - 1]) {
      inputRefs.current[index - 1].focus();
    }
  };

  const handleStep2Submit = async (e) => {
    e.preventDefault();
    setError('');
    
    let isValid = false;
    if (useEmergencyCode) {
      const cleanKey = emergencyKey.trim();
      const cleanPin = emergencyPin.trim();
      
      // Require BOTH Emergency Key AND Emergency PIN to be correct simultaneously
      if (cleanKey === 'PK-ADMIN-SECURE-984271-EMERGENCY-KEY' && cleanPin === '984271') {
        isValid = true;
      } else {
        setError("Invalid emergency security credentials. Both Key and PIN must be correct.");
        return;
      }
    } else {
      const enteredCode = otp.join('');
      if (enteredCode.length < 6) {
        setError("Please enter the complete 6-digit code from Google Authenticator.");
        return;
      }
      setLoading(true);
      isValid = await verifyTOTP(enteredCode, 'PARTWKADMINSECRET2FA');
      setLoading(false);
    }

    if (isValid) {
      sessionStorage.setItem('admin_2fa_verified', 'true');
      sessionStorage.setItem('admin_email', 'pkaramani@gmail.com');
      navigate('/');
    } else {
      setError("Invalid Google Authenticator code. Please check your app and try again.");
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-header">
          <div className="login-logo-circle">
            <ShieldCheck color="white" size={32} />
          </div>
          <h1>Partwk Admin Portal</h1>
          <p>{step === 1 ? "Step 1: Admin Password Authentication" : "Step 2: Google Authenticator 2FA"}</p>
        </div>

        {/* Step Indicator Bar */}
        <div className="step-indicator-bar">
          <div className={`step-dot ${step === 1 ? 'active' : 'completed'}`}>
            <div className="step-circle">{step > 1 ? '✓' : '1'}</div>
            <span>Password</span>
          </div>
          <div className={`step-line ${step > 1 ? 'active' : ''}`}></div>
          <div className={`step-dot ${step === 2 ? 'active' : ''}`}>
            <div className="step-circle">2</div>
            <span>Google 2FA</span>
          </div>
        </div>

        {error && (
          <div className="error-alert">
            <AlertCircle size={16} />
            <span>{error}</span>
          </div>
        )}

        {step === 1 ? (
          <form onSubmit={handleStep1Submit}>
            <div className="form-group">
              <label>Authorized Admin Email</label>
              <div className="input-with-icon">
                <Mail className="input-icon" size={18} />
                <input 
                  type="email" 
                  placeholder="admin@partwk.com" 
                  value={email} 
                  onChange={(e) => setEmail(e.target.value)} 
                  required 
                />
              </div>
            </div>

            <div className="form-group">
              <label>Admin Password</label>
              <div className="input-with-icon">
                <Lock className="input-icon" size={18} />
                <input 
                  type="password" 
                  placeholder="Enter your Firebase admin password" 
                  value={password} 
                  onChange={(e) => setPassword(e.target.value)} 
                  required 
                />
              </div>
            </div>

            <button type="submit" className="btn-submit-step" disabled={loading}>
              {loading ? "Verifying Password..." : <>Proceed to Google 2FA <ArrowRight size={18} /></>}
            </button>
          </form>
        ) : (
          <form onSubmit={handleStep2Submit}>
            {!useEmergencyCode ? (
              <div className="form-group">
                <label style={{ textAlign: 'center', marginBottom: '16px' }}>
                  Enter 6-Digit Code from Google Authenticator App
                </label>
                <div className="otp-container">
                  {otp.map((digit, index) => (
                    <input
                      key={index}
                      ref={(el) => (inputRefs.current[index] = el)}
                      type="text"
                      className="otp-input"
                      maxLength="1"
                      value={digit}
                      onChange={(e) => handleOtpChange(index, e.target.value)}
                      onKeyDown={(e) => handleKeyDown(index, e)}
                    />
                  ))}
                </div>
              </div>
            ) : (
              <div>
                <div className="form-group">
                  <label style={{ marginBottom: '8px', color: '#F59E0B' }}>Part 1: Emergency Backup Key</label>
                  <div className="input-with-icon">
                    <KeyRound className="input-icon" size={18} color="#F59E0B" />
                    <input 
                      type="password" 
                      placeholder="Enter emergency key (Part 1)" 
                      value={emergencyKey} 
                      onChange={(e) => setEmergencyKey(e.target.value)} 
                      required 
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label style={{ marginBottom: '8px', color: '#F59E0B' }}>Part 2: Emergency Backup PIN</label>
                  <div className="input-with-icon">
                    <Hash className="input-icon" size={18} color="#F59E0B" />
                    <input 
                      type="password" 
                      placeholder="Enter emergency PIN (Part 2)" 
                      value={emergencyPin} 
                      onChange={(e) => setEmergencyPin(e.target.value)} 
                      required 
                    />
                  </div>
                </div>
              </div>
            )}

            <button type="submit" className="btn-submit-step" disabled={loading}>
              {loading ? "Verifying 2FA..." : <>Verify & Access Dashboard <ShieldCheck size={18} /></>}
            </button>

            <div style={{ marginTop: '20px', textAlign: 'center' }}>
              <button 
                type="button" 
                onClick={() => { setUseEmergencyCode(!useEmergencyCode); setError(''); }}
                style={{ background: 'transparent', border: 'none', color: '#94A3B8', fontSize: '12px', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: '6px' }}
              >
                <KeyRound size={13} /> {useEmergencyCode ? "Use Google Authenticator App Code" : "Lost access to app? Use Emergency Backup Credentials"}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default Login;
