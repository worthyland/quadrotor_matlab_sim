%使用刚体力矩模型
%参考坐标系：世界坐标系NED
%返回状态量：位置和姿态相对于参考坐标系；速度和角速度相对机体ned坐标系（可以在此代码中修改）
%初始化参数在 mdl_quad.m 脚本文件中
function [sys,x0,str,ts] = quadrotor_dynamics(t,x,u,flag, quad, x0, n0, groundflag)

    warning off MATLAB:divideByZero
    
    global groundFlag;
        
    %ARGUMENTS
    %   u       Reference inputs                1x4
    %   tele    Enable telemetry (1 or 0)       1x1
    %   crash   Enable crash detection (1 or 0) 1x1
    %   init    Initial conditions              1x12
    
    %INPUTS
    %   u = [Tx Ty Tz T]
    %   Triaxial moments and thrusts                     1x4
    
    %CONTINUOUS STATES
    %   z      Position                         3x1   (x,y,z) in {W_ned}
    %   n      Attitude                         3x1   (Y,P,R) in {W_ned}
    %   v      Velocity                         3x1   (xd,yd,zd) in {W_ned}
    %   o      Angular velocity                 3x1   (wx,wy,wz)in {boby_ned}
    %
    % Notes: z-axis downward so altitude is -z(3)
    
    %CONTINUOUS STATE MATRIX MAPPING
    %   x = [z1 z2 z3 n1 n2 n3 z1 z2 z3 o1 o2 o3]
    
    %INITIAL CONDITIONS
    v0 = [0 0 0];               %   v0      Velocity Initial conditions         1x3
    o0 = [0 0 0];               %   o0      Ang. velocity initial conditions    1x3
    init = [x0 n0 v0 o0];       % x0 is the passed initial position 1x3
    groundFlag = groundflag;

    %CONTINUOUS STATE EQUATIONS
    %   z` = v
    %   v` = g*e3 - (1/m)*T*R*e3
    %   I*o` = -o X I*o + G + torq
    %   R = f(n)
    %   n` = inv(W)*o
    
    % Dispatch the flag.
    %
    switch flag
        case 0
            [sys,x0,str,ts]=mdlInitializeSizes(init, quad); % Initialization
        case 1
            sys = mdlDerivatives(t,x,u, quad); % Calculate derivatives
        case 3
            sys = mdlOutputs(t,x, quad); % Calculate outputs
        case { 2, 4, 9 } % Unused flags
            sys = [];
        otherwise
            error(['Unhandled flag = ',num2str(flag)]); % Error handling
    end
end % End of flyer2dynamics

%==============================================================
% mdlInitializeSizes
% Return the sizes, initial conditions, and sample times for the
% S-function.
%==============================================================
%
function [sys,x0,str,ts] = mdlInitializeSizes(init, quad)
    %
    % Call simsizes for a sizes structure, fill it in and convert it
    % to a sizes array.
    %
    sizes = simsizes;
    sizes.NumContStates  = 12;
    sizes.NumDiscStates  = 0;
    sizes.NumOutputs     = 12;
    sizes.NumInputs      = 4;
    sizes.DirFeedthrough = 0;
    sizes.NumSampleTimes = 1;
    sys = simsizes(sizes);
    %
    % Initialize the initial conditions.
    x0 = init;
    %
    % str is an empty matrix.
    str = [];
    %
    % Generic timesample
    ts = [0 0];
end % End of mdlInitializeSizes.


%==============================================================
% mdlDerivatives
% Calculate the state derivatives for the next timestep
%==============================================================
%
function sys = mdlDerivatives(t,x,u, quad)
    global a1s b1s groundFlag

    tau = u(1:3);
    T = u(4);
    
    %EXTRACT STATES FROM X
    z = x(1:3);   % position in {W_ned}
    n = x(4:6);   % RPY angles {W_ned}
    v = x(7:9);   % velocity in {W_ned}
    o = x(10:12); % angular velocity in {B_ned}
    
    %PREPROCESS ROTATION AND WRONSKIAN MATRICIES
    phi = n(1);    % yaw
    the = n(2);    % pitch
    psi = n(3);    % roll
    
    % rotz(phi)*roty(the)*rotx(psi)
    %R = [cos(the)*cos(phi) sin(psi)*sin(the)*cos(phi)-cos(psi)*sin(phi) cos(psi)*sin(the)*cos(phi)+sin(psi)*sin(phi);   %BBF > Inertial rotation matrix
    %     cos(the)*sin(phi) sin(psi)*sin(the)*sin(phi)+cos(psi)*cos(phi) cos(psi)*sin(the)*sin(phi)-sin(psi)*cos(phi);
    %     -sin(the)         sin(psi)*cos(the)                            cos(psi)*cos(the)];
    
    
    %Manual Construction
         Q3 = [cos(phi) -sin(phi) 0;sin(phi) cos(phi) 0;0 0 1];   % RZ %Rotation mappings
         Q2 = [cos(the) 0 sin(the);0 1 0;-sin(the) 0 cos(the)];   % RY
         Q1 = [1 0 0;0 cos(psi) -sin(psi);0 sin(psi) cos(psi)];   % RX
         R = Q3*Q2*Q1    %Rotation matrix
    %
    %    RZ * RY * RX
    iW = [0        sin(psi)          cos(psi);             %inverted Wronskian
          0        cos(psi)*cos(the) -sin(psi)*cos(the);
          cos(the) sin(psi)*sin(the) cos(psi)*sin(the)] / cos(the);
   
    %Body-fixed frame references
    e1 = [1;0;0];               %   ei      Body fixed frame references         3x1
    e2 = [0;1;0];
    e3 = [0;0;1];
   
    %RIGID BODY DYNAMIC MODEL
    dz = v;
    dn = iW*o;
    
    dv = quad.g*e3 - R*(1/quad.M)*T*e3;
    
    % vehicle can't fall below ground
    if groundFlag && (z(3) > 0)
        z(3) = 0;
        dz(3) = 0;
    end
    do = inv(quad.J)*(cross(-o,quad.J*o) + tau); %row sum of torques
    sys = [dz;dn;dv;do];   %This is the state derivative vector
end % End of mdlDerivatives.


%==============================================================
% mdlOutputs
% Calculate the output vector for this timestep
%==============================================================
%
function sys = mdlOutputs(t,x, quad)
    
    %TELEMETRY
    %if quad.verbose
        %disp(sprintf('%0.3f\t',t,x))
    %end
    
    % compute output vector as a function of state vector
    %   z      Position                         3x1   (x,y,z) 
    %   v      Velocity                         3x1   (xd,yd,zd)
    %   n      Attitude                         3x1   (Y,P,R)
    %   o      Angular velocity                 3x1   (Yd,Pd,Rd)
    
    n = x(4:6);   % RPY angles
    phi = n(1);    % yaw
    the = n(2);    % pitch
    psi = n(3);    % roll
    
    
    % rotz(phi)*roty(the)*rotx(psi)
    R = [cos(the)*cos(phi) sin(psi)*sin(the)*cos(phi)-cos(psi)*sin(phi) cos(psi)*sin(the)*cos(phi)+sin(psi)*sin(phi);   %BBF > Inertial rotation matrix
         cos(the)*sin(phi) sin(psi)*sin(the)*sin(phi)+cos(psi)*cos(phi) cos(psi)*sin(the)*sin(phi)-sin(psi)*cos(phi);
         -sin(the)         sin(psi)*cos(the)                            cos(psi)*cos(the)];
    
    
    % return velocity in the body frame
    sys = [ x(1:6);
           inv(R)*x(7:9);   % translational velocity mapped to body frame
           x(10:12)];    
    %sys = x;
end
% End of mdlOutputs.
