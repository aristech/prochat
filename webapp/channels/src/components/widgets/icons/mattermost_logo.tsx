// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

import React from 'react';
import type {CSSProperties} from 'react';
import {useIntl} from 'react-intl';

export default function MattermostLogo(props: React.HTMLAttributes<HTMLSpanElement>) {
    const {formatMessage} = useIntl();
    return (
        <span {...props}>
            <svg
                version='1.1'
                viewBox='0 0 112 112'
                xmlns='http://www.w3.org/2000/svg'
                role='img'
                aria-label={formatMessage({id: 'generic_icons.mattermost', defaultMessage: 'ProChat Logo'})}
            >
                <g transform="translate(-34.843 -50)" fill="#ff620d">
                    <polygon
                        points="131.61 126.4 131.68 126.36 131.69 73.588 90.862 50.011 90.843 50 90.843 61.406 121.81 79.289 121.8 120.65 90.843 138.52 90.843 149.93"
                        fill="#ff620d"
                    />
                    <polygon
                        points="59.883 132.06 59.878 90.692 90.843 72.81 90.843 61.403 90.824 61.414 50 84.992 50.006 137.76 50.075 137.8 90.843 161.33 90.843 149.92"
                        fill="#ff620d"
                    />
                </g>
            </svg>
        </span>
    );
}

const style: CSSProperties = {
    fillRule: 'evenodd',
    clipRule: 'evenodd',
};
