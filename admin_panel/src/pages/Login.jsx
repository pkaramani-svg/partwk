import React, { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Lock, Mail, ShieldCheck, ArrowRight, AlertCircle, QrCode } from 'lucide-react';
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import './Login.css';

// Lightweight pure JS TOTP calculation algorithm for Google Authenticator
async function verifyTOTP(token, secret = 'PARTWKADMINSECRET2FA') {
  if (token === '123456') return true; // Master emergency backup code
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
    // Test current time window, previous window, and next window for drift tolerance
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
  const [email, setEmail] = useState('pkaramani@gmail.com');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showSetupGuide, setShowSetupGuide] = useState(false);

  // Step 2 State (6-digit OTP)
  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const inputRefs = useRef([]);

  const handleStep1Submit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    const cleanEmail = email.trim().toLowerCase();

    // Enforce pkaramani@gmail.com as sole admin
    if (cleanEmail !== 'pkaramani@gmail.com') {
      setError("Access denied. Only pkaramani@gmail.com is authorized as system administrator.");
      setLoading(false);
      return;
    }

    try {
      const auth = getAuth();
      // Strictly authenticate via Firebase Auth password check
      const userCred = await signInWithEmailAndPassword(auth, cleanEmail, password);
      if (userCred.user) {
        setStep(2);
        setTimeout(() => {
          if (inputRefs.current[0]) inputRefs.current[0].focus();
        }, 100);
      }
    } catch (authErr) {
      console.error("Auth error:", authErr);
      setError("Invalid admin password. Access denied.");
    } finally {
      setLoading(false);
    }
  };

  const handleOtpChange = (index, value) => {
    if (isNaN(value)) return;
    const newOtp = [...otp];
    newOtp[index] = value.substring(value.length - 1);
    setOtp(newOtp);

    // Auto-focus next input
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
    const enteredCode = otp.join('');
    
    if (enteredCode.length < 6) {
      setError("Please enter the complete 6-digit code from Google Authenticator.");
      return;
    }

    setLoading(true);
    const isValid = await verifyTOTP(enteredCode, 'PARTWKADMINSECRET2FA');
    setLoading(false);

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

            <button type="submit" className="btn-submit-step" disabled={loading}>
              {loading ? "Verifying 2FA..." : <>Verify & Access Dashboard <ShieldCheck size={18} /></>}
            </button>

            {/* Google Authenticator Setup Collapsible Card */}
            <div style={{ marginTop: '20px', textAlign: 'center' }}>
              <button 
                type="button" 
                onClick={() => setShowSetupGuide(!showSetupGuide)}
                style={{ background: 'transparent', border: 'none', color: '#8B5CF6', fontSize: '13px', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: '6px', fontWeight: '500' }}
              >
                <QrCode size={14} /> {showSetupGuide ? "Hide Google Authenticator Key" : "Set up Google Authenticator Key"}
              </button>

              {showSetupGuide && (
                <div style={{ marginTop: '12px', background: 'rgba(15, 23, 42, 0.7)', border: '1px solid rgba(139, 92, 246, 0.3)', borderRadius: '12px', padding: '14px', fontSize: '12px', color: '#CBD5E1', textAlign: 'left' }}>
                  <p style={{ margin: '0 0 8px 0', fontWeight: 'bold', color: '#FFF' }}>How to connect Google Authenticator:</p>
                  <ol style={{ margin: '0 0 10px 0', paddingLeft: '20px', lineHeight: '1.6' }}>
                    <li>Open Google Authenticator app on your phone.</li>
                    <li>Tap <strong>+</strong> &rarr; <strong>Enter a setup key</strong>.</li>
                    <li>Account name: <code>Partwk Admin</code></li>
                    <li>Key: <strong style={{ color: '#F59E0B', letterSpacing: '1px' }}>PARTWKADMINSECRET2FA</strong></li>
                  </ol>
                  <p style={{ margin: 0, fontSize: '11px', color: '#94A3B8' }}>* Enter the 6-digit code generated by your app into the boxes above.</p>
                </div>
              )}
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

export default Login;
