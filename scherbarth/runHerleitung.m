clearvars;
herlT = tic;

out = evalc('hobbing');
out = evalc('losungBkartes');
out = evalc('hobbing2');

fprintf('[ %s ] Running the Herleitung took %.3f sec.\n',datestr(now,'HH:mm:ss'),toc(herlT));