clearvars
%% Schritt 0:
% Werkzeug
m=3;                % Modul
al_n= 20;           % Eingriffswinkel
z_WST= 24;          % Zaehnezahl
rWst = (m*z_WST)/2; % Werkstueckradius (Teilkreis)
d_WZ= 40;           % Werkzeugdurchmesser
rWz = d_WZ/2;       % Werkzeugradius
z_WZ= 1;            % Werkzeug Zaehnezahl
h_f0f =1.4;         % Werkzeug Kopf- und Fusshoehe
h_a0f= 1.17;
% Erzeugung der Werkzeugpunkte
[phi_WZ,r_WZ,h_WZ] = WZ(d_WZ, m, al_n, h_a0f, h_f0f, z_WZ);
% Maschine

x = rWst + rWz;     % Achsabstand des Schneckengetriebs
fX_WZrad=0;

fY_WZrad = 0;
y = 0;
Y_shift = 0;

fZ_WZrad = 0;
z = 75;

[a,b,c] = deal(0);
dirFac = -1;
f_WSTrad = z_WZ / z_WST * dirFac;
ga = 0;

A = 0;

%% Simulations-Setup
ptNm = numel(phi_WZ);
ptID = 3;                                   % select point for plotting
zInt = [60 90];                             % [zmin zmax]
zRes = 5;                                   % [Ebenen/mm] Aufloesung in z-Richtung
nDisE = ceil(zRes * abs(diff(zInt)));    % Anzahl diskrete Ebenen in z-Richtung, nach oben gerundet, damit geforderte Aufloesung auf jeden Fall eingehalten wird
nDisC = ceil(pi * rWst * sqrt(3) * zRes);   % Anzahl Vertices entlang dem Werkstueckumfangs (kreis), nach oben gerundet, ...
iterAbbr = 1e-3;        % zulaessiger Fehler bei der Iteration
dB = 0.1*pi;            % schrittweite beim seeken
logStr = {'no', 'yes'}; % logical string for log outputs
StopCriterion = 2*pi;
% preallocate variables
z_soll = linspace(zInt(2),zInt(1),nDisE);
Bsol  = NaN(1,ptNm,nDisE);   % Loesungsvektor
iters = NaN(nDisE,1);               % Vektor der notwendigen Iterationsschritte
err   = NaN(nDisE,1);               % vector of errors
zSolInd = NaN(nDisE,1);             % vektor of Indizies der simulierten z Werte
% init variables
n = 1;                              % absoluter zaehler der simulierten Schritte
B = 0;                              % Startwert fuer B
jumpB = 2.5/2*pi;                   % Sprungweite nach Schnitt
m = 1;                              % index fuer z_soll
mS = 1;                             % Sicherheitsabstand fuer Loesungsstart ab der zweiten Umdrehung
k = 1;                              % Vorfaktor zum Verschieben der Loesung um bereits zurueck gelegten Winkel des Werkzeugs
validIter = true;
engaged = false;                    % Werkzeug im Eingriff
runSim = true;                      % soll simulation ausgeuehrt werden
prevEng = false;                    % war Werkzeug beim vorherigen Iterationsschritt im Eingriff
% werkstueck polygons
cver = circle(rWst,nDisC,[0,0]);            % Vertices der Werkstueck-Polygone
orPgon = polyshape(cver','Simplify',false);	% originales Werkstueckpolgons
wkst = repmat(orPgon,nDisE,1);              % Array der Werkstueckpolygone
sIDLuT = repmat({ones(nDisC,1)},nDisE,1);   % cell-array der vertex classification
% rotate the odd numbered polyshapes by half a rotational space
oddind = logical(mod(1:nDisE,2));
wkst(oddind) = wkst(oddind).rotate( rad2deg( pi/(nDisC) ));
clearvars oddind
% werkzeug polygon
[cWZ(1,:),cWZ(2,:)] = pol2cart(phi_WZ,r_WZ,h_WZ);  % kartesische werkzeug koordinaten
wz = polyshape(cWZ','Simplify',false);
clearvars cver cWZ

% dH = waitbar(0,'Running sim...','Name','Running Sim','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
% setappdata(dH,'canceling',0);

% Definition der Funktion
bfun = @(B,z_soll,k) k*pi - phi_WZ + asin((z - c - z_soll + B*fZ_WZrad + sin(A)*(y + Y_shift + B*fY_WZrad - h_WZ))./(r_WZ*cos(A)));
% tool angle to z-height
tAng2zH = @(B,nP) z - c + B *fZ_WZrad + sin(A)*(y + Y_shift + B*fY_WZrad - h_WZ(nP)) + r_WZ(nP) * cos(A) * sin(B + phi_WZ(nP));
posFun = @(B) [x.*cos(ga + B.*f_WSTrad) - b.*sin(ga + B.*f_WSTrad) - a.*cos(ga + B.*f_WSTrad) + B.*fX_WZrad.*cos(ga + B.*f_WSTrad) + r_WZ.*cos(phi_WZ).*(cos(ga + B.*f_WSTrad).*cos(B) - sin(ga + B.*f_WSTrad).*sin(A).*sin(B)) - r_WZ.*sin(phi_WZ).*(cos(ga + B.*f_WSTrad).*sin(B) + sin(ga + B.*f_WSTrad).*cos(B).*sin(A)) + Y_shift.*sin(ga + B.*f_WSTrad).*cos(A) - h_WZ.*sin(ga + B.*f_WSTrad).*cos(A) + y.*sin(ga + B.*f_WSTrad).*cos(A) + B.*fY_WZrad.*sin(ga + B.*f_WSTrad).*cos(A);... x-Komponente
                a.*sin(ga + B.*f_WSTrad) - x.*sin(ga + B.*f_WSTrad) - b.*cos(ga + B.*f_WSTrad) - r_WZ.*cos(phi_WZ).*(sin(ga + B.*f_WSTrad).*cos(B) + cos(ga + B.*f_WSTrad).*sin(A).*sin(B)) - B.*fX_WZrad.*sin(ga + B.*f_WSTrad) + r_WZ.*sin(phi_WZ).*(sin(ga + B.*f_WSTrad).*sin(B) - cos(ga + B.*f_WSTrad).*cos(B).*sin(A)) + Y_shift.*cos(ga + B.*f_WSTrad).*cos(A) - h_WZ.*cos(ga + B.*f_WSTrad).*cos(A) + y.*cos(ga + B.*f_WSTrad).*cos(A) + B.*fY_WZrad.*cos(ga + B.*f_WSTrad).*cos(A);... y-Komponente
                z - c + B.*fZ_WZrad + Y_shift.*sin(A) - h_WZ.*sin(A) + y.*sin(A) + B.*fY_WZrad.*sin(A) + r_WZ.*cos(A).*cos(B).*sin(phi_WZ) + r_WZ.*cos(A).*sin(B).*cos(phi_WZ)]; % z-Komponente
% position of tool point depending on tool angle
posFunID = @(B,ptID) [x.*cos(ga + B.*f_WSTrad) - b.*sin(ga + B.*f_WSTrad) - a.*cos(ga + B.*f_WSTrad) + B.*fX_WZrad.*cos(ga + B.*f_WSTrad) + r_WZ(ptID).*cos(phi_WZ(ptID)).*(cos(ga + B.*f_WSTrad).*cos(B) - sin(ga + B.*f_WSTrad).*sin(A).*sin(B)) - r_WZ(ptID).*sin(phi_WZ(ptID)).*(cos(ga + B.*f_WSTrad).*sin(B) + sin(ga + B.*f_WSTrad).*cos(B).*sin(A)) + Y_shift.*sin(ga + B.*f_WSTrad).*cos(A) - h_WZ(ptID).*sin(ga + B.*f_WSTrad).*cos(A) + y.*sin(ga + B.*f_WSTrad).*cos(A) + B.*fY_WZrad.*sin(ga + B.*f_WSTrad).*cos(A);... x-Komponente
                      a.*sin(ga + B.*f_WSTrad) - x.*sin(ga + B.*f_WSTrad) - b.*cos(ga + B.*f_WSTrad) - r_WZ(ptID).*cos(phi_WZ(ptID)).*(sin(ga + B.*f_WSTrad).*cos(B) + cos(ga + B.*f_WSTrad).*sin(A).*sin(B)) - B.*fX_WZrad.*sin(ga + B.*f_WSTrad) + r_WZ(ptID).*sin(phi_WZ(ptID)).*(sin(ga + B.*f_WSTrad).*sin(B) - cos(ga + B.*f_WSTrad).*cos(B).*sin(A)) + Y_shift.*cos(ga + B.*f_WSTrad).*cos(A) - h_WZ(ptID).*cos(ga + B.*f_WSTrad).*cos(A) + y.*cos(ga + B.*f_WSTrad).*cos(A) + B.*fY_WZrad.*cos(ga + B.*f_WSTrad).*cos(A);... y-Komponente
                      z - c + B.*fZ_WZrad + Y_shift.*sin(A) - h_WZ(ptID).*sin(A) + y.*sin(A) + B.*fY_WZrad.*sin(A) + r_WZ(ptID).*cos(A).*cos(B).*sin(phi_WZ(ptID)) + r_WZ(ptID).*cos(A).*sin(B).*cos(phi_WZ(ptID))]; % z-Komponente
% distance of tool point from workpiece centre depending on tool angle
distWst = @(B,ptID) sqrt((a.*sin(ga + B.*f_WSTrad) - x.*sin(ga + B.*f_WSTrad) - b.*cos(ga + B.*f_WSTrad) - r_WZ(ptID).*cos(phi_WZ(ptID)).*(sin(ga + B.*f_WSTrad).*cos(B) + cos(ga + B.*f_WSTrad).*sin(A).*sin(B)) - B.*fX_WZrad.*sin(ga + B.*f_WSTrad) + r_WZ(ptID).*sin(phi_WZ(ptID)).*(sin(ga + B.*f_WSTrad).*sin(B) - cos(ga + B.*f_WSTrad).*cos(B).*sin(A)) + Y_shift.*cos(ga + B.*f_WSTrad).*cos(A) - h_WZ(ptID).*cos(ga + B.*f_WSTrad).*cos(A) + y.*cos(ga + B.*f_WSTrad).*cos(A) + B.*fY_WZrad.*cos(ga + B.*f_WSTrad).*cos(A)).^2 + (x.*cos(ga + B.*f_WSTrad) - b.*sin(ga + B.*f_WSTrad) - a.*cos(ga + B.*f_WSTrad) + B.*fX_WZrad.*cos(ga + B.*f_WSTrad) + r_WZ(ptID).*cos(phi_WZ(ptID)).*(cos(ga + B.*f_WSTrad).*cos(B) - sin(ga + B.*f_WSTrad).*sin(A).*sin(B)) - r_WZ(ptID).*sin(phi_WZ(ptID)).*(cos(ga + B.*f_WSTrad).*sin(B) + sin(ga + B.*f_WSTrad).*cos(B).*sin(A)) + Y_shift.*sin(ga + B.*f_WSTrad).*cos(A) - h_WZ(ptID).*sin(ga + B.*f_WSTrad).*cos(A) + y.*sin(ga + B.*f_WSTrad).*cos(A) + B.*fY_WZrad.*sin(ga + B.*f_WSTrad).*cos(A)).^2);

pltSim = plotSimulation(zInt,rWst,orPgon,wz,ptNm,ptID,bfun,tAng2zH,posFun,distWst);
%% Schritt N:
v1T = tic;
while runSim
    % detect start configuration
    pltSim.plotTraj(B);
    while not(engaged) % Seek-Loop
        B = B + dB;
        engaged = checkEng(posFun(B),zInt,rWst);
        pltSim.plotSeek(B);
    end
    
    while true      % detect starting plane in workpiece
        B0 = B;                     % Ausgangswinkel der Iteration ist der Winkel des letzten Schrittes
        B  =  bfun(B0,z_soll(m),k);	% Berechnen des Winkels mit Startwert
        engaged = checkEng(posFun(B),zInt,rWst);
        if engaged
            prevm = m;              % save z-height we engaged at, this is where we will start next time
            break
        else
            pltSim.plotCandidate(B);
            m = m+1;
        end
    end
        
        
        
    while engaged   % Schnittschleife
        
        l = 0;                          % noch keine Iterationen
        
        while true      % Iterationsschleife
            l = l+1;                    % weitere Iteration ist notwendig
            B0 = B;                     % Ausgangswinkel der Iteration ist der Winkel des letzten Schrittes
            B  =  bfun(B0,z_soll(m),k);	% Berechnen des Winkels mit Startwert
            
            % Hardstop: gesuchter Wert z_soll tiefer als erreichbar
            if ~isreal(B)
                validIter = false;
                B = B0;                 % letzter berechneter Wert ist der gueltige Endwinkel
                warning('Gesuchter Punkt zu tief.')
            end
            
            % Iterationsschleifen Abbruch
            % entweder nicht mehr im Eingriff, oder genauigkeit erreicht
            div = sum(abs(B-B0));     % error
            if div > iterAbbr
            else
                break
            end
            
        end

        if not(validIter)
            validIter = true;       % reset flag
            engaged = false;        % durch erreichen eines ungueltigen Iterationszustandes sind wir auch nicht mehr im Eingriff
            break
        end
        % pruefen, ob wir noch im Eingriff sind
        engaged = checkEng(posFun(B),zInt,rWst);
        if not(engaged)
            break
        end
        n = n+1;                    % ein weiterer, gueltiger Schritt wurde simuliert
        % plotten des punktes
        pltSim.plotCut(B);
        % plotten der geometrie
        
        % schneiden der polygone
        for pt = 1:ptNm
            wzV = posFun(B(pt))';
            wz.Vertices = wzV(:,1:2);
            [wkst(m),sID,vID] = wkst(m).subtract(wz,'KeepCollinearPoints',true);
            wkstV = [wkst(m).Vertices,repmat(z_soll(m),wkst(m).numsides,1)];
            sID(sID == 1) = sIDLuT{m}(vID(sID == 1));       % manipulation der aktuellen klassifizierung
            sIDLuT{m} = sID;
        end
        pltSim.toolMvmt(wkstV,wzV);
        pltSim.pointCloud(extractVert(wkst,z_soll),vertcat(sIDLuT{:}));
        % Ergebnisse wegschreiben
        Bsol(1,:,n) = B;
        zSolInd(n) = m;
        iters(n) = l;
        err(n) =  div;   % Fehler mitloggen
        
        m = m+1;
    end
    % Schnitt ist beendet
    B = max(B);             % nur der Winkel des zuletzt im Eingriff gewesenen Punktes behalten
    B = B + jumpB;             % wir koennen um eine halbe Umdrehung springen
    m = prevm - mS;              % wieder bei der letzten obersten Ebene beginnen
    k = k+2;
    pltSim.finishedCut(B);
    
    % simulation stop criterion
    curAngC = abs(f_WSTrad * B + ga);
    fprintf('Cut finished. Workpiece is at %.3f rad.\n', curAngC);
    if curAngC > StopCriterion
        runSim = false;
    end
%     if getappdata(dH,'canceling')
%         break
%     end
end

pltSim.stop;
% Ausgabe
fprintf('Dauer Loesung durch Iteration: %.4f sec.\n',toc(v1T))
% delete(dH);

vert = extractVert(wkst,z_soll);        % extract vertices into single Mx3 array
sIDLuT = single(vertcat(sIDLuT{:}));    % extract vertex classes into single Mx1 array